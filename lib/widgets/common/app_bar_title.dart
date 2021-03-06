import 'package:flutter/material.dart';

class TappableAppBarTitle extends StatelessWidget {
  final GestureTapCallback onTap;
  final Widget child;

  const TappableAppBarTitle({
    this.onTap,
    @required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // use a `Container` with a dummy color to make it expand
      // so that we can also detect taps around the title `Text`
      child: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: EdgeInsets.symmetric(horizontal: NavigationToolbar.kMiddleSpacing),
        color: Colors.transparent,
        height: kToolbarHeight,
        child: child,
      ),
    );
  }
}
