import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pg from 'pg';
import jwt from 'jsonwebtoken';
import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { randomUUID } from 'crypto';

dotenv.config();

const { Pool } = pg;

const PORT = Number(process.env.PORT || 4000);
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = Number(process.env.DB_PORT || 5432);
const DB_USER = process.env.DB_USER || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD || '';
const DB_NAME = process.env.DB_NAME || 'ridewave';
const DB_ADMIN_DB = process.env.DB_ADMIN_DB || 'postgres';
const JWT_SECRET = process.env.JWT_SECRET || 'change_me';
const FIREBASE_SERVICE_ACCOUNT_PATH =
  process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './serviceAccountKey.json';

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

function initFirebaseAdmin() {
  if (admin.apps.length) return;
  const serviceAccount = JSON.parse(
    readFileSync(FIREBASE_SERVICE_ACCOUNT_PATH, 'utf8')
  );
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
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
      firebase_uid text UNIQUE NOT NULL,
      first_name text NOT NULL,
      last_name text NOT NULL,
      email text NOT NULL,
      phone text NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    )
  `);
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
  initFirebaseAdmin();
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

  app.post('/api/auth/session', async (req, res) => {
    const auth = req.headers.authorization || '';
    const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!idToken) {
      return res.status(401).json({ error: 'Missing Firebase token.' });
    }
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      const { token } = issueJwt(decoded.uid);
      return res.json({ token, uid: decoded.uid });
    } catch (err) {
      console.error('Firebase token verify failed', err);
      return res.status(401).json({ error: 'Invalid Firebase token.' });
    }
  });

  app.post('/api/auth/refresh', async (req, res) => {
    const auth = req.headers.authorization || '';
    const idToken = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!idToken) {
      return res.status(401).json({ error: 'Missing Firebase token.' });
    }
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      const { token } = issueJwt(decoded.uid);
      return res.json({ token, uid: decoded.uid });
    } catch (err) {
      return res.status(401).json({ error: 'Invalid Firebase token.' });
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

  app.post('/api/users', requireJwt(), async (req, res) => {
    const { firebase_uid, first_name, last_name, email, phone } = req.body || {};

    if (!firebase_uid || !first_name || !last_name || !email || !phone) {
      return res.status(400).json({ error: 'Missing required fields.' });
    }

    if (firebase_uid !== req.user.uid) {
      return res.status(403).json({ error: 'UID mismatch.' });
    }

    try {
      const query = `
        INSERT INTO users (firebase_uid, first_name, last_name, email, phone)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (firebase_uid)
        DO UPDATE SET
          first_name = EXCLUDED.first_name,
          last_name = EXCLUDED.last_name,
          email = EXCLUDED.email,
          phone = EXCLUDED.phone,
          updated_at = now()
        RETURNING *
      `;
      const values = [firebase_uid, first_name, last_name, email, phone];
      const { rows } = await pool.query(query, values);
      return res.json({ user: rows[0] });
    } catch (err) {
      console.error('User upsert failed', err);
      return res.status(500).json({ error: 'Server error.' });
    }
  });

  app.get('/api/users/:firebaseUid', requireJwt(), async (req, res) => {
    const { firebaseUid } = req.params;
    if (firebaseUid !== req.user.uid) {
      return res.status(403).json({ error: 'UID mismatch.' });
    }
    try {
      const { rows } = await pool.query(
        'SELECT * FROM users WHERE firebase_uid = $1',
        [firebaseUid]
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'User not found.' });
      }
      return res.json({ user: rows[0] });
    } catch (err) {
      console.error('User fetch failed', err);
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
