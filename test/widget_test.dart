import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:make_my_money_last/main.dart';
import 'package:make_my_money_last/providers/app_provider.dart';

void main() {
  testWidgets('App builds with Provider (splash while not initialized)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const App3ML(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Make My Money Last'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
