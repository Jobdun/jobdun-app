part of 'register_page.dart';

// Step 1 (role selection) widgets for the register flow, split into a `part`
// so `register_page.dart` stays under the file-size budget. Private,
// single-use, co-located with the page state. No behaviour change.

// ── Step 1: Role selection ────────────────────────────────────────────────────

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    super.key,
    required this.selectedRole,
    required this.onRolePicked,
    required this.onGoToLogin,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
    required this.isBusy,
    required this.c,
    required this.tt,
  });

  final UserRole? selectedRole;
  final ValueChanged<UserRole> onRolePicked;
  final VoidCallback onGoToLogin;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;
  final bool isBusy;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand lockup (compact horizontal) ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              JobdunLogo(variant: LogoVariant.mark, height: 32.r),
              Gap(10.w),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.brandFlame.createShader(bounds),
                child: Text(
                  'JOBDUN',
                  style: tt.displaySmall!.copyWith(
                    color:
                        Colors.white, // intentional: ShaderMask requires white
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),

          Gap(AppSpacing.xl.h),

          Text(
            'WHICH SIDE ARE YOU ON?',
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              letterSpacing: 0.5,
            ),
          ),
          Gap(6.h),
          Text(
            'Tap to continue — you can switch later.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),

          Gap(AppSpacing.lg.h),

          // ── Role cards — tap-to-advance ───────────────────────────────────
          _RoleCard(
            role: UserRole.builder,
            icon: AppIcons.builder,
            label: "I'M HIRING",
            description: 'Post jobs. Review applicants. Manage crews.',
            selected: selectedRole == UserRole.builder,
            onTap: () => onRolePicked(UserRole.builder),
            c: c,
            tt: tt,
          ),
          Gap(12.h),
          _RoleCard(
            role: UserRole.trade,
            icon: AppIcons.briefcase,
            label: "I'M LOOKING FOR WORK",
            description: 'Browse jobs. Apply. Get hired.',
            selected: selectedRole == UserRole.trade,
            onTap: () => onRolePicked(UserRole.trade),
            c: c,
            tt: tt,
          ),

          Gap(AppSpacing.xl.h),

          // ── SSO alternative — matches /login icon-tile row ────────────────
          // Same Google · Apple · Phone trio as LoginPage so users land on a
          // single consistent SSO surface across both auth entry points.
          _OrDivider(c: c, tt: tt),
          Gap(AppSpacing.md.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SocialAuthButton.google(
                key: const Key('register.sso.google'),
                onTap: isBusy ? () {} : onGoogle,
                isLoading: isBusy,
              ),
              SocialAuthButton.apple(
                key: const Key('register.sso.apple'),
                onTap: isBusy ? () {} : onApple,
                isLoading: isBusy,
              ),
              SocialAuthButton.phone(
                key: const Key('register.sso.phone'),
                onTap: isBusy ? () {} : onPhone,
                isLoading: isBusy,
              ),
            ],
          ),

          Gap(AppSpacing.lg.h),

          // ── Already have an account ────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: onGoToLogin,
              child: RichText(
                text: TextSpan(
                  style: tt.bodySmall!.copyWith(color: c.text3),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'LOG IN',
                      style: tt.bodySmall!.copyWith(
                        color: c.actionInk,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Gap(AppSpacing.xl.h),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  final UserRole role;
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(AppSpacing.lg.r),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: selected ? c.action : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: selected ? c.action : c.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  icon,
                  size: AppIconSize.md.r,
                  color: selected
                      ? Colors
                            .white // intentional: white-on-action
                      : c.text2,
                ),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.labelLarge!.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      description,
                      style: tt.bodySmall!.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              Gap(AppSpacing.sm.w),
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.md.r,
                color: selected ? c.action : c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "── or ──" section divider ──────────────────────────────────────────────
// Mirrors the divider on /login above the SSO icon row so both auth pages
// share the same "email path above, social path below" rhythm.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.c, required this.tt});

  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Divider(color: c.border, thickness: 1, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Text('or', style: tt.bodySmall!.copyWith(color: c.text3)),
        ),
        Expanded(child: Divider(color: c.border, thickness: 1, height: 1)),
      ],
    );
  }
}
