import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_room_app/pages/playlists/widgets/track_reorder_gesture.dart';

void main() {
  testWidgets('a mouse drag moves the grabbed track', (tester) async {
    final order = await _pumpList(tester);

    final first = tester.getCenter(find.text('A'));
    final gesture = await tester.startGesture(
      first,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(order, ['B', 'A', 'C']);
  });

  testWidgets('a finger swipe does not reorder before the press', (
    tester,
  ) async {
    final order = await _pumpList(tester);

    final first = tester.getCenter(find.text('A'));
    final gesture = await tester.startGesture(
      first,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(order, ['A', 'B', 'C']);
  });

  testWidgets('a finger press then drag reorders the track', (tester) async {
    final order = await _pumpList(tester);

    final first = tester.getCenter(find.text('A'));
    final gesture = await tester.startGesture(
      first,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(order, ['B', 'A', 'C']);
  });
}

Future<List<String>> _pumpList(WidgetTester tester) async {
  final order = ['A', 'B', 'C'];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: order.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final label = order[index];
                    return TrackReorderGesture(
                      key: ValueKey(label),
                      index: index,
                      enabled: true,
                      child: SizedBox(height: 56, child: Text(label)),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  return order;
}
