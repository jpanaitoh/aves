import 'package:aves/theme/icons.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkChip extends StatelessWidget {
  final Widget leading;
  final String text;
  final String url;
  final Color color;
  final TextStyle textStyle;

  static const borderRadius = BorderRadius.all(Radius.circular(8));

  const LinkChip({
    Key key,
    this.leading,
    @required this.text,
    @required this.url,
    this.color,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: (textStyle ?? TextStyle()).copyWith(color: color),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () async {
          if (await canLaunch(url)) {
            await launch(url);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: 8),
              ],
              Text(text),
              SizedBox(width: 8),
              Builder(
                builder: (context) => Icon(
                  AIcons.openInNew,
                  size: DefaultTextStyle.of(context).style.fontSize,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
