import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_bottom_nav_bar/cupertino_bottom_nav_bar.dart';
import 'package:material_ui/material_ui.dart';

const _style = AppGlassNavigationStyle(
  labelStyle: TextStyle(fontFamily: 'Ahem', fontSize: 10, height: 1.35),
);
const _dockKey = Key('flutter_glass_navigation_dock');

void main() {
  for (final brightness in Brightness.values) {
    for (final spacing in ['letter', 'word']) {
      testWidgets(
        '${brightness.name} $spacing spacing keeps a complete caption inside its target',
        (tester) async {
          final labels = spacing == 'letter'
              ? const ['Saved', 'Chats', 'Stars']
              : const ['My list', 'My feed', 'My page'];
          await _pumpDock(tester, labels: labels, brightness: brightness);
          final baseline = _naturalCaptionSize(tester, labels.first);
          // Give each baseline caption only two pixels beyond its required padding.
          // The override, not a pre-existing long-label layout, crosses the threshold.
          final targetWidth = baseline.width + _style.labelPadding * 2 + 2;
          final width =
              targetWidth * labels.length +
              _style.horizontalInset * 2 +
              _style.resolvedHorizontalContentInset * 2;
          await _pumpDock(
            tester,
            labels: labels,
            width: width,
            brightness: brightness,
          );
          expect(
            tester.getSize(_target(labels.first)).width,
            greaterThanOrEqualTo(baseline.width + _style.labelPadding * 2),
          );

          await _pumpDock(
            tester,
            labels: labels,
            width: width,
            brightness: brightness,
            letterSpacing: spacing == 'letter' ? 4 : null,
            wordSpacing: spacing == 'word' ? 20 : null,
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(labels.first),
          );
          final effectiveStyle = (paragraph.text as TextSpan).style!;
          expect(
            spacing == 'letter'
                ? effectiveStyle.letterSpacing
                : effectiveStyle.wordSpacing,
            spacing == 'letter' ? 4 : 20,
          );
          final effective = _naturalCaptionSize(tester, labels.first);
          expect(effective.width, greaterThan(baseline.width));
          final renderingException = tester.takeException();
          expect(
            tester.getSize(_target(labels.first)).width,
            greaterThanOrEqualTo(effective.width + _style.labelPadding * 2),
            reason:
                'Measure the effective RichText span, not its constrained render-box '
                'width or the unmodified Text.style.',
          );
          expect(renderingException, isNull);

          await _pumpDock(
            tester,
            labels: labels,
            width: width,
            brightness: brightness,
          );
          expect(_naturalCaptionSize(tester, labels.first), baseline);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${brightness.name} line-height spacing grows the complete icon and caption lane',
      (tester) async {
        const labels = ['Saved', 'Chats', 'Stars'];
        await _pumpDock(tester, labels: labels, brightness: brightness);
        final baseline = _naturalCaptionSize(tester, labels.first);
        final baselineHeight = tester.getSize(find.byKey(_dockKey)).height;
        await _pumpDock(
          tester,
          labels: labels,
          lineHeight: 3,
          brightness: brightness,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(labels.first),
        );
        expect((paragraph.text as TextSpan).style!.height, 3);
        final effective = _naturalCaptionSize(tester, labels.first);
        expect(effective.height, greaterThan(baseline.height));
        final renderingException = tester.takeException();
        expect(
          tester.getSize(_target(labels.first)).height,
          greaterThanOrEqualTo(
            _style.iconArea + _style.labelGap + effective.height,
          ),
          reason:
              'The action lane must fit the actual single-line caption height.',
        );
        expect(
          tester.getSize(find.byKey(_dockKey)).height,
          greaterThan(baselineHeight),
        );
        expect(renderingException, isNull);
        await _pumpDock(tester, labels: labels, brightness: brightness);
        expect(tester.getSize(find.byKey(_dockKey)).height, baselineHeight);
        expect(_naturalCaptionSize(tester, labels.first), baseline);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

// RenderParagraph.size is constrained and may conceal visible text overflow.
// Reshape its already-resolved span without a width limit instead of rebuilding
// Text.style, which intentionally lacks the accessibility overrides under test.
Size _naturalCaptionSize(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

Finder _target(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Future<void> _pumpDock(
  WidgetTester tester, {
  required List<String> labels,
  double width = 390,
  double? letterSpacing,
  double? wordSpacing,
  double? lineHeight,
  Brightness brightness = Brightness.light,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery.applyTextStyleOverrides(
      letterSpacingOverride: letterSpacing,
      wordSpacingOverride: wordSpacing,
      lineHeightScaleFactorOverride: lineHeight,
      paragraphSpacingOverride: null,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CustomGlassNavigationDockWidget(
              items: [
                for (final label in labels)
                  AppGlassNavigationItem(
                    icon: Icons.circle_outlined,
                    label: label,
                  ),
              ],
              selectedIndex: 0,
              onItemSelected: (_) {},
              style: _style,
              preferNative: false,
            ),
          ),
        ),
      ),
    ),
  ),
);
