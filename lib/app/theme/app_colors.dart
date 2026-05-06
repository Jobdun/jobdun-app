import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primitives — fixed, never theme-dependent
  static const foundation  = Color(0xFF252D34);
  static const action      = Color(0xFFCC4A10);
  static const actionBg    = Color(0xFFFAE4D8);
  static const actionTx    = Color(0xFF7A2808);
  static const verified    = Color(0xFF0D8A5A);
  static const verifiedBg  = Color(0xFFE6F7F1);
  static const verifiedTx  = Color(0xFF0D6644);
  static const urgent      = Color(0xFFC73B2E);
  static const urgentBg    = Color(0xFFFDECEA);
  static const urgentTx    = Color(0xFFA32E24);
  static const available   = Color(0xFF1A7AD4);
  static const availableBg = Color(0xFFE6F3FF);
  static const availableTx = Color(0xFF1254A0);

  // Semantic — light mode
  static const background  = Color(0xFFF4F6F8);
  static const surface     = Color(0xFFEAEEF2);
  static const card        = Color(0xFFFFFFFF);
  static const border      = Color(0xFFD4D9DF);
  static const text1       = Color(0xFF252D34);
  static const text2       = Color(0xFF5A6872);
  static const text3       = Color(0xFFA0ACB8);

  // Non-semantic utility
  static const star        = Color(0xFFF59E0B); // star/rating only
  static const white       = Color(0xFFFFFFFF);
}

abstract final class AppDarkColors {
  static const background  = Color(0xFF0E1216);
  static const surface     = Color(0xFF1C2428);
  static const card        = Color(0xFF252D34);
  static const border      = Color(0xFF303A44);
  static const text1       = Color(0xFFE8ECF2);
  static const text2       = Color(0xFF7A8898);
  static const text3       = Color(0xFF505C68);
  // Primary button FLIPS — foundation is invisible on dark bg
  static const btnPri      = Color(0xFFCC4A10);
}

abstract final class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 20.0;   // screen horizontal padding — always 20px
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const badge  = 5.0;
  static const chip   = 8.0;
  static const btn    = 9.0;
  static const card   = 14.0;  // NEVER exceed 14px
  static const input  = 10.0;
  static const avatar = 10.0;
}
