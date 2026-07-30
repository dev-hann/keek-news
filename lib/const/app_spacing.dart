import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double p2 = 2;
  static const double p4 = 4;
  static const double p6 = 6;
  static const double p8 = 8;
  static const double p12 = 12;
  static const double p16 = 16;
  static const double p20 = 20;
  static const double p24 = 24;
  static const double p32 = 32;
  static const double p40 = 40;
  static const double p48 = 48;
  static const double p56 = 56;
  static const double p64 = 64;

  static const EdgeInsets edgeAll4 = EdgeInsets.all(p4);
  static const EdgeInsets edgeAll8 = EdgeInsets.all(p8);
  static const EdgeInsets edgeAll12 = EdgeInsets.all(p12);
  static const EdgeInsets edgeAll16 = EdgeInsets.all(p16);
  static const EdgeInsets edgeAll24 = EdgeInsets.all(p24);
  static const EdgeInsets edgeAll32 = EdgeInsets.all(p32);

  static const EdgeInsets edgeH4V2 = EdgeInsets.symmetric(
    horizontal: p4,
    vertical: p2,
  );
  static const EdgeInsets edgeH8V4 = EdgeInsets.symmetric(
    horizontal: p8,
    vertical: p4,
  );
  static const EdgeInsets edgeH12V6 = EdgeInsets.symmetric(
    horizontal: p12,
    vertical: p6,
  );
  static const EdgeInsets edgeH16V8 = EdgeInsets.symmetric(
    horizontal: p16,
    vertical: p8,
  );

  static const EdgeInsets edgeH16 = EdgeInsets.symmetric(horizontal: p16);
  static const EdgeInsets edgeH20 = EdgeInsets.symmetric(horizontal: p20);
  static const EdgeInsets edgeH24 = EdgeInsets.symmetric(horizontal: p24);
  static const EdgeInsets edgeV4 = EdgeInsets.symmetric(vertical: p4);
  static const EdgeInsets edgeV8 = EdgeInsets.symmetric(vertical: p8);

  static const EdgeInsets edgeOnlyBottom4 = EdgeInsets.only(bottom: p4);
  static const EdgeInsets edgeOnlyBottom8 = EdgeInsets.only(bottom: p8);
  static const EdgeInsets edgeOnlyBottom12 = EdgeInsets.only(bottom: p12);
  static const EdgeInsets edgeOnlyBottom16 = EdgeInsets.only(bottom: p16);

  static const SizedBox sbH4 = SizedBox(height: p4);
  static const SizedBox sbH6 = SizedBox(height: p6);
  static const SizedBox sbH8 = SizedBox(height: p8);
  static const SizedBox sbH12 = SizedBox(height: p12);
  static const SizedBox sbH16 = SizedBox(height: p16);
  static const SizedBox sbH24 = SizedBox(height: p24);
  static const SizedBox sbH32 = SizedBox(height: p32);
  static const SizedBox sbH48 = SizedBox(height: p48);

  static const SizedBox sbW4 = SizedBox(width: p4);
  static const SizedBox sbW8 = SizedBox(width: p8);
  static const SizedBox sbW12 = SizedBox(width: p12);
  static const SizedBox sbW16 = SizedBox(width: p16);
  static const SizedBox sbW24 = SizedBox(width: p24);
}
