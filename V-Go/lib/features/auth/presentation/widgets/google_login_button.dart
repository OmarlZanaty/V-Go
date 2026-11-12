import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/get_route.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../data/model/social_login_provider.dart';
import '../views/google_complete_profile_view.dart';
import '../logic/cubit/auth_cubit.dart';
import '../logic/cubit/auth_state_extension.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({
    super.key,
    this.provider = SocialLoginProvider.google,
    this.listen = true,
    this.height = 54,
    this.radius = 50,
  });

  final SocialLoginProvider provider;
  final bool listen;
  final double height;
  final double radius;

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  bool _completingProfile = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          widget.listen &&
          !_completingProfile &&
          current.provider == widget.provider &&
          _listenWhen(current),
      listener: (context, state) async {
        if (state.status.isLoginWithGoogleSuccess) {
          context.pop();
          context.pushNamedAndRemoveUntil(
            getRoute(),
            predicate: (route) => false,
          );
        } else if (state.status.isLoginWithGoogleFailure) {
          context.pop();
          errorToast(context, 'حدث خطا', state.errorMessage);
        } else if (state.status.isLoginWithGoogleLoading) {
          loadingDialog(context);
        } else if (state.status == AuthStatus.loginWithGoogleNewUser) {
          context.pop();
          final cubit = context.read<AuthCubit>();
          _completingProfile = true;
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: GoogleCompleteProfileView(
                provider: state.provider,
                idToken: state.googleIdToken,
                name: state.googleName,
                photo: state.googlePhoto,
              ),
            ),
          ));
          _completingProfile = false;
        } else if (state.status.isInitial) {
          context.pop();
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          if (context.read<AuthCubit>().state.status.isLoginWithGoogleLoading) {
            return;
          }
          FocusManager.instance.primaryFocus?.unfocus();
          if (widget.provider == SocialLoginProvider.apple) {
            context.read<AuthCubit>().appleLogin();
          } else {
            context.read<AuthCubit>().googleLogin();
          }
        },
        label: Text(
          widget.provider == SocialLoginProvider.apple
              ? 'تسجيل الدخول باستخدام Apple'
              : 'تسجيل الدخول باستخدام ',
          style: widget.provider == SocialLoginProvider.apple
              ? AppStyle.styleMedium16.copyWith(color: AppColors.white)
              : AppStyle.styleMedium16,
        ),
        icon: widget.provider == SocialLoginProvider.apple
            ? const Icon(Icons.apple, color: Colors.white, size: 34)
            : Image.asset('assets/images/google.png', width: 34),
        style: ElevatedButton.styleFrom(
          iconAlignment: IconAlignment.end,
          backgroundColor: widget.provider == SocialLoginProvider.apple
              ? Colors.black
              : Colors.transparent,
          foregroundColor: AppColors.white,
          minimumSize: Size.fromHeight(widget.height),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.white),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }

  bool _listenWhen(AuthState state) =>
      state.status.isLoginWithGoogleSuccess ||
      state.status.isLoginWithGoogleFailure ||
      state.status.isLoginWithGoogleLoading ||
      state.status == AuthStatus.loginWithGoogleNewUser ||
      state.status.isInitial;
}
