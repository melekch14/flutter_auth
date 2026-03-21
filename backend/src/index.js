import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pg from 'pg';
import jwt from 'jsonwebtoken';
import twilio from 'twilio';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';

dotenv.config();

const { Pool } = pg;

const PORT = Number(process.env.PORT || 5000);
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = Number(process.env.DB_PORT || 5432);
const DB_USER = process.env.DB_USER || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD || '';
const DB_NAME = process.env.DB_NAME || 'ridewave';
const DB_ADMIN_DB = process.env.DB_ADMIN_DB || 'postgres';
const JWT_SECRET = process.env.JWT_SECRET || 'change_me';
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || '';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || '';
const TWILIO_VERIFY_SERVICE_SID = process.env.TWILIO_VERIFY_SERVICE_SID || '';

function maskValue(value) {
  if (!value) return '(empty)';
  if (value.length <= 6) return value;
  return `${value.slice(0, 4)}...${value.slice(-4)}`;
}

console.log('Twilio config:', {
  account: maskValue(TWILIO_ACCOUNT_SID),
  verifyService: maskValue(TWILIO_VERIFY_SERVICE_SID),
});

const adminConfig = {
  host: DB_HOST,
  port: DB_PORT,
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_ADMIN_DB,
};

const appConfig = {
  host: DB_HOST,
  port: DB_PORT,
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
};

let poolRef = null;
let twilioClient = null;

function initTwilio() {
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_VERIFY_SERVICE_SID) {
    throw new Error('Missing Twilio configuration');
  }
  twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
}

async function createDatabaseIfNotExists() {
  const adminPool = new Pool(adminConfig);
  try {
    const { rows } = await adminPool.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [DB_NAME]
    );
    if (rows.length === 0) {
      await adminPool.query(`CREATE DATABASE "${DB_NAME}"`);
      console.log(`Created database: ${DB_NAME}`);
    }
  } finally {
    await adminPool.end();
  }
}

async function runMigrations(pool) {
  await pool.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto"');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      first_name text NOT NULL,
      last_name text NOT NULL,
      email text NOT NULL,
      phone text NOT NULL,
      password_hash text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await pool.query(
    'CREATE UNIQUE INDEX IF NOT EXISTS users_email_key ON users (email)'
  );
  await pool.query(
    'CREATE UNIQUE INDEX IF NOT EXISTS users_phone_key ON users (phone)'
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS revoked_tokens (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      jti text UNIQUE NOT NULL,
      expires_at timestamptz NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);
}

function issueJwt(uid) {
  const jti = randomUUID();
  const token = jwt.sign({ uid, jti }, JWT_SECRET, { expiresIn: '7d' });
  return { token, jti };
}

function requireJwt() {
  return async (req, res, next) => {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!token) {
      return res.status(401).json({ error: 'Missing token.' });
    }
    try {
      const payload = jwt.verify(token, JWT_SECRET);
      const { rows } = await poolRef.query(
        'SELECT 1 FROM revoked_tokens WHERE jti = $1 AND expires_at > now()',
        [payload.jti]
      );
      if (rows.length > 0) {
        return res.status(401).json({ error: 'Token revoked.' });
      }
      req.user = payload;
      return next();
    } catch (err) {
      return res.status(401).json({ error: 'Invalid token.' });
    }
  };
}

async function bootstrap() {
  initTwilio();
  await createDatabaseIfNotExists();
  const pool = new Pool(appConfig);
  poolRef = pool;
  await runMigrations(pool);

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  app.post('/api/auth/send-otp', async (req, res) => {
    const { phone, email } = req.body || {};
    if (!phone) {
      return res.status(400).json({ error: 'Phone required.' });
    }
    if (email) {
      const { rows } = await pool.query(
        'SELECT 1 FROM users WHERE email = $1 OR phone = $2 LIMIT 1',
        [email, phone]
      );
      if (rows.length > 0) {
        return res
          .status(409)
          .json({ error: 'Email or phone already exists.' });
      }
    }
    try {
      const verification = await twilioClient.verify.v2
        .services(TWILIO_VERIFY_SERVICE_SID)
        .verifications.create({ to: phone, channel: 'sms' });
      return res.json({ status: verification.status });
    } catch (err) {
      console.error('Twilio send failed', err);
      return res.status(500).json({ error: 'OTP send failed.' });
    }
  });

  app.post('/api/auth/check-availability', async (req, res) => {
    const { email, phone } = req.body || {};
    if (!email || !phone) {
      return res.status(400).json({ error: 'Email and phone required.' });
    }
    try {
      const { rows } = await pool.query(
        'SELECT 1 FROM users WHERE email = $1 OR phone = $2 LIMIT 1',
        [email, phone]
      );
      if (rows.length > 0) {
        return res
          .status(409)
          .json({ error: 'Email or phone already exists.' });
      }
      return res.json({ available: true });
    } catch (err) {
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.post('/api/auth/verify-otp', async (req, res) => {
    const { phone, code } = req.body || {};
    if (!phone || !code) {
      return res.status(400).json({ error: 'Phone and code required.' });
    }
    try {
      const check = await twilioClient.verify.v2
        .services(TWILIO_VERIFY_SERVICE_SID)
        .verificationChecks.create({ to: phone, code });
      const approved = check.status === 'approved';
      if (!approved) {
        return res.status(400).json({ error: 'Invalid code.' });
      }
      return res.json({ approved: true });
    } catch (err) {
      console.error('Twilio verify failed', err);
      return res.status(500).json({ error: 'OTP verify failed.' });
    }
  });

  app.post('/api/auth/register', async (req, res) => {
    const { first_name, last_name, email, phone, password, code } =
      req.body || {};
    if (!first_name || !last_name || !email || !phone || !password || !code) {
      return res.status(400).json({ error: 'Missing required fields.' });
    }

    try {
      const check = await twilioClient.verify.v2
        .services(TWILIO_VERIFY_SERVICE_SID)
        .verificationChecks.create({ to: phone, code });
      if (check.status !== 'approved') {
        return res.status(400).json({ error: 'Invalid code.' });
      }

      const passwordHash = await bcrypt.hash(password, 12);
      const query = `
        INSERT INTO users (first_name, last_name, email, phone, password_hash)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, first_name, last_name, email, phone
      `;
      const values = [first_name, last_name, email, phone, passwordHash];
      const { rows } = await pool.query(query, values);
      const { token } = issueJwt(rows[0].id);
      return res.json({ token, user: rows[0] });
    } catch (err) {
      if (err?.code === '23505') {
        return res.status(409).json({ error: 'Email or phone already exists.' });
      }
      console.error('Register failed', err);
      return res.status(500).json({ error: 'Register failed.' });
    }
  });

  app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required.' });
    }

    try {
      const { rows } = await pool.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );
      if (rows.length === 0) {
        return res.status(401).json({ error: 'Invalid credentials.' });
      }
      const user = rows[0];
      const ok = await bcrypt.compare(password, user.password_hash);
      if (!ok) {
        return res.status(401).json({ error: 'Invalid credentials.' });
      }
      const { token } = issueJwt(user.id);
      return res.json({
        token,
        user: {
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          phone: user.phone,
        },
      });
    } catch (err) {
      console.error('Login failed', err);
      return res.status(500).json({ error: 'Login failed.' });
    }
  });

  app.post('/api/auth/logout', requireJwt(), async (req, res) => {
    try {
      const { jti, exp } = req.user;
      const expiresAt = new Date(exp * 1000);
      await pool.query(
        'INSERT INTO revoked_tokens (jti, expires_at) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [jti, expiresAt]
      );
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.get('/api/auth/me', requireJwt(), async (req, res) => {
    try {
      const { rows } = await pool.query(
        'SELECT id, first_name, last_name, email, phone FROM users WHERE id = $1',
        [req.user.uid]
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'User not found.' });
      }
      return res.json({ user: rows[0] });
    } catch (err) {
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.put('/api/auth/me', requireJwt(), async (req, res) => {
    const { first_name, last_name, email } = req.body || {};
    if (!first_name || !last_name || !email) {
      return res.status(400).json({ error: 'All fields are required.' });
    }
    try {
      const { rows: dup } = await pool.query(
        'SELECT 1 FROM users WHERE email = $1 AND id <> $2 LIMIT 1',
        [email, req.user.uid]
      );
      if (dup.length > 0) {
        return res.status(409).json({ error: 'Email already exists.' });
      }

      const { rows } = await pool.query(
        `UPDATE users
         SET first_name = $1, last_name = $2, email = $3, updated_at = now()
         WHERE id = $4
         RETURNING id, first_name, last_name, email, phone`,
        [first_name, last_name, email, req.user.uid]
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'User not found.' });
      }
      return res.json({ user: rows[0] });
    } catch (err) {
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.put('/api/auth/change-password', requireJwt(), async (req, res) => {
    const { current_password, new_password, confirm_password } = req.body || {};
    if (!current_password || !new_password || !confirm_password) {
      return res.status(400).json({ error: 'All fields are required.' });
    }
    if (new_password !== confirm_password) {
      return res.status(400).json({ error: 'Passwords do not match.' });
    }
    try {
      const { rows } = await pool.query(
        'SELECT password_hash FROM users WHERE id = $1',
        [req.user.uid]
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'User not found.' });
      }
      const ok = await bcrypt.compare(
        current_password,
        rows[0].password_hash
      );
      if (!ok) {
        return res.status(401).json({ error: 'Current password is incorrect.' });
      }
      const newHash = await bcrypt.hash(new_password, 12);
      await pool.query(
        'UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2',
        [newHash, req.user.uid]
      );
      return res.json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.listen(PORT, () => {
    console.log(`Backend running on http://localhost:${PORT}`);
  });
}

bootstrap().catch((err) => {
  console.error('Startup failed', err);
  process.exit(1);
});
