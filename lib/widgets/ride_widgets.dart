import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../theme/app_theme.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E1118),
            Color(0xFF0B141E),
            Color(0xFF0F1C2B),
          ],
        ),
      ),
      child: const Stack(
        children: [
          Positioned(
            top: -120,
            right: -60,
            child: GlowOrb(
              size: 220,
              color: Color(0x332EE59D),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: GlowOrb(
              size: 260,
              color: Color(0x2224C8FF),
            ),
          ),
        ],
      ),
    );
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, 1],
        ),
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.stroke.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentSoft],
            ),
          ),
          child: const Icon(Icons.navigation_rounded, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RideWave',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Move smarter, arrive calm',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class DividerRow extends StatelessWidget {
  const DividerRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(height: 1, color: AppColors.stroke),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(height: 1, color: AppColors.stroke),
        ),
      ],
    );
  }
}

class SocialTile extends StatelessWidget {
  const SocialTile({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class RideTextField extends StatelessWidget {
  const RideTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        isDense: true,
        constraints: const BoxConstraints(minHeight: 46),
      ),
    );
  }
}

class CountryCodePhoneField extends StatefulWidget {
  const CountryCodePhoneField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.dialCode,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueNotifier<String> dialCode;
  final VoidCallback? onChanged;

  @override
  State<CountryCodePhoneField> createState() => _CountryCodePhoneFieldState();
}

class _CountryCodePhoneFieldState extends State<CountryCodePhoneField> {
  CountryCode _selected = CountryCode(dialCode: '+216', code: 'TN');

  @override
  void initState() {
    super.initState();
    if (widget.dialCode.value.isNotEmpty) {
      _selected = CountryCode(dialCode: widget.dialCode.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: widget.controller,
        keyboardType: TextInputType.phone,
        onChanged: (_) => widget.onChanged?.call(),
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 46),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 46),
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.phone_outlined, size: 18),
              const SizedBox(width: 8),
              CountryCodePicker(
                onChanged: (code) {
                  setState(() => _selected = code);
                  final dial = code.dialCode;
                  if (dial != null && dial.isNotEmpty) {
                    widget.dialCode.value = dial;
                  }
                  widget.onChanged?.call();
                },
                initialSelection: _selected.code ?? widget.dialCode.value,
                favorite: const ['+216', '+1', '+33', '+44'],
                flagWidth: 18,
                showFlag: true,
                showDropDownButton: true,
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: true,
                padding: EdgeInsets.zero,
                builder: (code) {
                  final dialCode = code?.dialCode ?? '';
                  final flagUri = code?.flagUri;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (flagUri != null)
                        Image.asset(
                          flagUri,
                          package: 'country_code_picker',
                          width: 18,
                          height: 14,
                          fit: BoxFit.cover,
                        ),
                      if (flagUri != null) const SizedBox(width: 6),
                      Text(
                        dialCode,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                    ],
                  );
                },
                textStyle: Theme.of(context).textTheme.bodySmall,
                dialogTextStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textPrimary),
                searchStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textPrimary),
                dialogBackgroundColor: AppColors.surface,
                barrierColor: Colors.black.withOpacity(0.7),
                searchDecoration: InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                dialogSize: const Size(360, 520),
              ),
              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 18,
                color: AppColors.stroke,
              ),
              const SizedBox(width: 8),
            ],
          ),
          prefixIconColor: AppColors.textMuted,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        onPressed: onTap ?? () {},
        child: Text(label),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.stroke.withOpacity(0.7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: AppColors.textPrimary,
          textStyle: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onPressed: onTap ?? () {},
        child: Text(label),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class RideTile extends StatelessWidget {
  const RideTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  final String title;
  final String subtitle;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.stroke.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.directions_car_filled, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
