import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uem_eats/models/profile_model.dart';
import 'package:uem_eats/models/vendor_model.dart';
import 'package:uem_eats/models/menu_item_model.dart';
import 'package:uem_eats/models/order_model.dart';
import 'package:uem_eats/providers/admin_provider.dart';
import 'package:uem_eats/providers/cart_provider.dart';
import 'package:uem_eats/core/utils/currency_formatter.dart';
import 'package:uem_eats/core/constants/app_constants.dart';
import 'package:uem_eats/repositories/payment_repository.dart';
import 'package:uem_eats/models/order_item_model.dart';
import 'package:uem_eats/providers/order_provider.dart';
import 'package:uem_eats/providers/vendor_provider.dart';
import 'package:uem_eats/screens/admin/dashboard/admin_dashboard_screen.dart';
import 'package:uem_eats/screens/admin/orders/admin_orders_screen.dart';
import 'package:uem_eats/screens/vendor/dashboard/vendor_dashboard_screen.dart';
import 'package:uem_eats/screens/vendor/orders/vendor_order_history_screen.dart';

void main() {
  group('Domain Models Test', () {
    test('ProfileModel deserialization correctly identifies roles', () {
      final student = ProfileModel.fromJson({
        'id': 'test-uuid-1',
        'name': 'Rahul Sharma',
        'email': 'rahul@uem.edu.in',
        'role': 'STUDENT',
      });

      expect(student.isStudentOrFaculty, isTrue);
      expect(student.isVendor, isFalse);

      final vendor = ProfileModel.fromJson({
        'id': 'test-uuid-2',
        'name': 'Canteen Admin',
        'email': 'vendor@uem.edu.in',
        'role': 'VENDOR',
      });

      expect(vendor.isVendor, isTrue);
      expect(vendor.isStudentOrFaculty, isFalse);
    });

    test('VendorModel deserialization parses active state correctly', () {
      final vendor = VendorModel.fromJson({
        'id': 'vendor-1',
        'vendor_name': 'Campus Bites',
        'location': 'Ground Floor',
        'is_active': true,
      });

      expect(vendor.vendorName, 'Campus Bites');
      expect(vendor.isActive, isTrue);
    });

    test('ProfileModel handles missing id and falls back safely', () {
      final profile = ProfileModel.fromJson({
        'name': 'Priya Das',
        'email': 'priya@uem.edu.in',
        'role': 'STUDENT',
      });

      expect(profile.id, '');
      expect(profile.name, 'Priya Das');
      expect(profile.role, 'STUDENT');
    });

    test('OrderModel deserializes vendor orders with joined profiles safely', () {
      final order = OrderModel.fromJson({
        'id': 'ord-101',
        'vendor_id': 'vendor-1',
        'item_total': '120.00',
        'total_amount': '124.00',
        'status': 'PENDING',
        'profiles': {
          'name': 'Ananya Roy',
          'role': 'FACULTY',
        },
        'vendors': {
          'vendor_name': 'Campus Bites',
          'location': 'Ground Floor',
        },
        'order_items': [
          {
            'item_name': 'Sandwich',
            'price': 60.0,
            'quantity': 2,
          }
        ],
      });

      expect(order.id, 'ord-101');
      expect(order.customer?.name, 'Ananya Roy');
      expect(order.customer?.role, 'FACULTY');
      expect(order.vendor?.vendorName, 'Campus Bites');
      expect(order.items.length, 1);
    });
  });

  group('CartNotifier & Single-Vendor Business Logic', () {
    final vendorA = VendorModel(id: 'v1', vendorName: 'Canteen A');
    final vendorB = VendorModel(id: 'v2', vendorName: 'Canteen B');

    final itemA = MenuItemModel(
      id: 'item-1',
      vendorId: 'v1',
      name: 'Chicken Biryani',
      price: 150.00,
    );

    final itemB = MenuItemModel(
      id: 'item-2',
      vendorId: 'v2',
      name: 'Cold Coffee',
      price: 60.00,
    );

    test('Adds item and calculates total with ₹4 convenience fee', () {
      final cartNotifier = CartNotifier();

      final added = cartNotifier.addItem(itemA, vendorA);
      expect(added, isTrue);

      final state = cartNotifier.state;
      expect(state.items.length, 1);
      expect(state.subtotal, 150.00);
      expect(state.convenienceFee, AppConstants.currentConvenienceFee);
      expect(state.grandTotal, 154.00);
    });

    test('Enforces single-vendor rule: blocks adding from second vendor', () {
      final cartNotifier = CartNotifier();

      // Add from Vendor A
      cartNotifier.addItem(itemA, vendorA);

      // Attempt adding from Vendor B while cart has Vendor A items
      final addedFromB = cartNotifier.addItem(itemB, vendorB);
      expect(addedFromB, isFalse); // Blocked by single-vendor rule
      expect(cartNotifier.state.vendor?.id, 'v1');

      // Now replace cart with vendor B item
      cartNotifier.replaceCartWithItem(itemB, vendorB);
      expect(cartNotifier.state.vendor?.id, 'v2');
      expect(cartNotifier.state.items.length, 1);
      expect(cartNotifier.state.items.first.item.id, 'item-2');
    });
  });

  group('Razorpay Models Test', () {
    test('PaymentOrderInitResponse deserialization parses all fields properly', () {
      final response = PaymentOrderInitResponse.fromJson({
        'keyId': 'rzp_test_12345',
        'orderId': 'order_DBJOWzybf0sJbb',
        'amount': 6200,
        'currency': 'INR',
        'verifiedTotal': 62.0,
        'itemTotal': 58.0,
        'convenienceFee': 4.0,
      });

      expect(response.keyId, 'rzp_test_12345');
      expect(response.orderId, 'order_DBJOWzybf0sJbb');
      expect(response.amount, 6200);
      expect(response.currency, 'INR');
      expect(response.verifiedTotal, 62.0);
      expect(response.itemTotal, 58.0);
      expect(response.convenienceFee, 4.0);
    });
  });

  group('Role & Earnings Tests', () {
    test('ProfileModel identifies Admin and Faculty roles correctly', () {
      final admin = ProfileModel.fromJson({
        'id': 'admin-uuid',
        'name': 'System Administrator',
        'email': 'admin@uem.edu.in',
        'role': 'ADMIN',
      });
      expect(admin.isAdmin, isTrue);
      expect(admin.isVendor, isFalse);
      expect(admin.isStudentOrFaculty, isFalse);

      final faculty = ProfileModel.fromJson({
        'id': 'faculty-uuid',
        'name': 'Prof. Mukherjee',
        'email': 'mukherjee@uem.edu.in',
        'role': 'FACULTY',
      });
      expect(faculty.isAdmin, isFalse);
      expect(faculty.isStudentOrFaculty, isTrue);
    });

    test('OrderModel vendor earnings excludes ₹4 platform convenience fee', () {
      final order = OrderModel.fromJson({
        'id': 'ord-earn-1',
        'vendor_id': 'vendor-1',
        'item_total': 250.00,
        'convenience_fee': 4.00,
        'total_amount': 254.00,
        'status': 'COMPLETED',
      });

      expect(order.vendorEarnings, 250.00);
      expect(order.vendorAmount, 250.00);
      expect(order.orderSubtotal, 250.00);
      expect(order.totalAmount, 254.00);
      expect(order.customerTotal, 254.00);
      expect(order.convenienceFee, 4.00);
      expect(order.platformFee, 4.00);
    });

    test('Scenario 1: ₹100 item + ₹4 fee = customer pays ₹104 -> vendor sees ₹100', () {
      final order = OrderModel.fromJson({
        'id': 'ord-test-1',
        'vendor_id': 'v1',
        'item_total': 100.00,
        'convenience_fee': 4.00,
        'total_amount': 104.00,
        'status': 'PENDING',
        'order_items': [
          {'item_name': 'Chicken Biriani', 'price': 100.0, 'quantity': 1}
        ],
      });

      expect(order.customerTotal, 104.00);
      expect(order.totalAmount, 104.00);
      expect(order.platformFee, 4.00);
      expect(order.orderSubtotal, 100.00);
      expect(order.vendorAmount, 100.00);
      expect(order.vendorEarnings, 100.00);
    });

    test('Scenario 2: ₹200 item + ₹8 fee = customer pays ₹208 -> vendor sees ₹200', () {
      final order = OrderModel.fromJson({
        'id': 'ord-test-2',
        'vendor_id': 'v1',
        'item_total': 200.00,
        'convenience_fee': 8.00,
        'total_amount': 208.00,
        'status': 'COMPLETED',
        'order_items': [
          {'item_name': 'Mutton Biryani', 'price': 200.0, 'quantity': 1}
        ],
      });

      expect(order.customerTotal, 208.00);
      expect(order.platformFee, 8.00);
      expect(order.orderSubtotal, 200.00);
      expect(order.vendorAmount, 200.00);
    });

    test('Scenario 3: Multiple items -> vendor sees item subtotal, not customer total', () {
      final order = OrderModel.fromJson({
        'id': 'ord-test-3',
        'vendor_id': 'v1',
        'item_total': 310.00,
        'convenience_fee': 4.00,
        'total_amount': 314.00,
        'status': 'PENDING',
        'order_items': [
          {'item_name': 'Paneer Butter Masala', 'price': 180.0, 'quantity': 1},
          {'item_name': 'Butter Naan', 'price': 40.0, 'quantity': 2},
          {'item_name': 'Sweet Lassi', 'price': 50.0, 'quantity': 1},
        ],
      });

      expect(order.customerTotal, 314.00);
      expect(order.platformFee, 4.00);
      expect(order.orderSubtotal, 310.00);
      expect(order.vendorAmount, 310.00);
      expect(order.calculatedItemTotal, 310.00);
    });

    test('Scenario 4: Fallback dynamic calculation when item_total is 0 but items are present', () {
      final order = OrderModel.fromJson({
        'id': 'ord-test-4',
        'vendor_id': 'v1',
        'item_total': 0.0,
        'convenience_fee': 4.00,
        'total_amount': 154.00,
        'status': 'PENDING',
        'order_items': [
          {'item_name': 'Chicken Roll', 'price': 75.0, 'quantity': 2},
        ],
      });

      expect(order.orderSubtotal, 150.00);
      expect(order.vendorAmount, 150.00);
      expect(order.customerTotal, 154.00);
    });

    test('Scenario 5: Fallback dynamic calculation when item_total is 0 and items are empty', () {
      final order = OrderModel.fromJson({
        'id': 'ord-test-5',
        'vendor_id': 'v1',
        'item_total': 0.0,
        'convenience_fee': 4.00,
        'total_amount': 104.00,
        'status': 'PENDING',
      });

      expect(order.orderSubtotal, 100.00);
      expect(order.vendorAmount, 100.00);
      expect(order.customerTotal, 104.00);
    });

    test('Scenario 6: Order status states (PENDING, COMPLETED, CANCELLED) preserve correct vendor amount', () {
      final pendingOrder = OrderModel(
        id: 'ord-p',
        vendorId: 'v1',
        itemTotal: 100.00,
        convenienceFee: 4.00,
        totalAmount: 104.00,
        status: 'PENDING',
      );
      expect(pendingOrder.isPending, isTrue);
      expect(pendingOrder.vendorAmount, 100.00);
      expect(pendingOrder.customerTotal, 104.00);

      final completedOrder = OrderModel(
        id: 'ord-c',
        vendorId: 'v1',
        itemTotal: 100.00,
        convenienceFee: 4.00,
        totalAmount: 104.00,
        status: 'COMPLETED',
      );
      expect(completedOrder.isCompleted, isTrue);
      expect(completedOrder.vendorAmount, 100.00);
      expect(completedOrder.customerTotal, 104.00);
    });
  });

  group('Formatters Test', () {
    test('CurrencyFormatter produces correct INR format', () {
      expect(CurrencyFormatter.format(154.0), contains('154'));
      expect(CurrencyFormatter.format(null), '₹0.00');
    });
  });

  group('Admin Dashboard Responsive Layout Tests', () {
    testWidgets('Renders all management cards without overflow on narrow 320px width screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminUsersProvider.overrideWith((ref) async => [
              ProfileModel(id: 'u1', name: 'User 1', email: 'u1@uem.edu.in', role: 'STUDENT'),
            ]),
            adminVendorsProvider.overrideWith((ref) async => [
              VendorModel(id: 'v1', vendorName: 'Very Long Vendor Name Canteen Food Court Stall', isActive: true),
            ]),
            adminOrdersProvider.overrideWith((ref) async => [
              OrderModel(id: 'o1', vendorId: 'v1', itemTotal: 100, totalAmount: 104, status: 'COMPLETED'),
            ]),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vendor & Canteen Management'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Global Paid Orders'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });

    testWidgets('Renders properly on standard 360px Android phone screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminUsersProvider.overrideWith((ref) async => [
              ProfileModel(id: 'u1', name: 'User 1', email: 'u1@uem.edu.in', role: 'STUDENT'),
            ]),
            adminVendorsProvider.overrideWith((ref) async => [
              VendorModel(id: 'v1', vendorName: 'Canteen Stall 1', isActive: true),
            ]),
            adminOrdersProvider.overrideWith((ref) async => [
              OrderModel(id: 'o1', vendorId: 'v1', itemTotal: 100, totalAmount: 104, status: 'COMPLETED'),
            ]),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vendor & Canteen Management'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Global Paid Orders'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });
  });

  group('Vendor Dashboard Screen Widget Tests', () {
    testWidgets('Vendor incoming order displays ₹100.00 and does NOT display ₹104.00 or ₹4.00 fee', (tester) async {
      final testOrder = OrderModel(
        id: 'ord-test-vendor-1',
        vendorId: 'v1',
        itemTotal: 100.00,
        convenienceFee: 4.00,
        totalAmount: 104.00,
        status: 'PENDING',
        customer: ProfileModel(id: 'c1', name: 'John Doe', email: 'john@uem.edu.in', role: 'STUDENT'),
        items: [
          OrderItemModel(id: 'item-1', itemName: 'Chicken Biriani', price: 100.00, quantity: 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myVendorStoreProvider.overrideWith((ref) async => VendorModel(id: 'v1', vendorName: 'Campus Bites', isActive: true)),
            vendorOrdersProvider.overrideWith((ref) async => [testOrder]),
          ],
          child: const MaterialApp(
            home: VendorDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Food item row
      expect(find.text('1x Chicken Biriani'), findsOneWidget);

      // Payment label
      expect(find.text('PAID ONLINE (Razorpay)'), findsOneWidget);

      // Vendor payable amount beside payment label must be ₹100.00 (once for item line, once for total)
      expect(find.text('₹100.00'), findsNWidgets(2));

      // Customer total ₹104.00 and convenience fee ₹4.00 must NOT appear
      expect(find.text('₹104.00'), findsNothing);
      expect(find.text('₹4.00'), findsNothing);
    });

    testWidgets('Vendor completed order displays ₹100.00 and does NOT display ₹104.00', (tester) async {
      final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final completedOrder = OrderModel(
        id: 'ord-test-vendor-2',
        vendorId: 'v1',
        itemTotal: 100.00,
        convenienceFee: 4.00,
        totalAmount: 104.00,
        status: 'COMPLETED',
        orderDate: todayStr,
        customer: ProfileModel(id: 'c1', name: 'Jane Smith', email: 'jane@uem.edu.in', role: 'STUDENT'),
        items: [
          OrderItemModel(id: 'item-2', itemName: 'Chicken Biriani', price: 100.00, quantity: 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myVendorStoreProvider.overrideWith((ref) async => VendorModel(id: 'v1', vendorName: 'Campus Bites', isActive: true)),
            vendorOrdersProvider.overrideWith((ref) async => [completedOrder]),
          ],
          child: const MaterialApp(
            home: VendorDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Completed tab
      await tester.tap(find.text('✅ Completed'));
      await tester.pumpAndSettle();

      // Verify item and vendor amount
      expect(find.text('1x Chicken Biriani'), findsOneWidget);
      expect(find.text('PAID ONLINE (Razorpay)'), findsOneWidget);
      expect(find.text('₹100.00'), findsNWidgets(2));

      // Customer total ₹104.00 must NOT appear
      expect(find.text('₹104.00'), findsNothing);
      expect(find.text('₹4.00'), findsNothing);
    });
  });

  group('ListTile & ExpansionTile Material Structure Tests', () {
    testWidgets('AdminOrdersScreen wraps ExpansionTile in Material without invisible ink splash assertion', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldHandler?.call(details);
      };

      try {
        final sampleOrder = OrderModel(
          id: 'ord-admin-test-1',
          vendorId: 'v1',
          itemTotal: 150.00,
          convenienceFee: 4.00,
          totalAmount: 154.00,
          status: 'PENDING',
          orderDate: '2026-09-27',
          customer: ProfileModel(id: 'c1', name: 'John Doe', email: 'john@uem.edu.in', role: 'STUDENT'),
          items: [
            OrderItemModel(id: 'item-1', itemName: 'Paneer Roll', price: 75.00, quantity: 2),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminOrdersProvider.overrideWith((ref) async => [sampleOrder]),
            ],
            child: const MaterialApp(
              home: AdminOrdersScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify ExpansionTile is present
        expect(find.byType(ExpansionTile), findsOneWidget);

        // Verify Material ancestor with 14px rounded corners and white color
        final materialFinder = find.ancestor(
          of: find.byType(ExpansionTile),
          matching: find.byType(Material),
        );
        expect(materialFinder, findsWidgets);

        final materialWidget = tester.widget<Material>(materialFinder.first);
        expect(materialWidget.color, Colors.white);
        expect(materialWidget.borderRadius, BorderRadius.circular(14));
        expect(materialWidget.clipBehavior, Clip.antiAlias);

        // Tap the tile to expand
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();

        // Verify expanded content is visible
        expect(find.text('ORDER ITEMS'), findsOneWidget);
        expect(find.text('2x'), findsOneWidget);
        expect(find.text('Paneer Roll'), findsOneWidget);

        // Tap the tile to collapse
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();

        // Assert NO error matches "ListTile background color or ink splashes may be invisible"
        final invisibleInkErrors = errors.where((e) =>
            e.exceptionAsString().contains('ListTile background color or ink splashes may be invisible'));
        expect(invisibleInkErrors, isEmpty);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets('VendorOrderHistoryScreen wraps ExpansionTile in Material without invisible ink splash assertion', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldHandler?.call(details);
      };

      try {
        final sampleOrder = OrderModel(
          id: 'ord-vendor-hist-1',
          vendorId: 'v1',
          itemTotal: 200.00,
          convenienceFee: 4.00,
          totalAmount: 204.00,
          status: 'COMPLETED',
          orderDate: '2026-09-27',
          customer: ProfileModel(id: 'c2', name: 'Alice Smith', email: 'alice@uem.edu.in', role: 'STUDENT'),
          items: [
            OrderItemModel(id: 'item-2', itemName: 'Veg Thali', price: 200.00, quantity: 1),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              myVendorStoreProvider.overrideWith((ref) async => VendorModel(id: 'v1', vendorName: 'Campus Bites', isActive: true)),
              vendorOrdersProvider.overrideWith((ref) async => [sampleOrder]),
            ],
            child: const MaterialApp(
              home: VendorOrderHistoryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify ExpansionTile is present
        expect(find.byType(ExpansionTile), findsOneWidget);

        // Verify Material ancestor with 14px rounded corners and white color
        final materialFinder = find.ancestor(
          of: find.byType(ExpansionTile),
          matching: find.byType(Material),
        );
        expect(materialFinder, findsWidgets);

        final materialWidget = tester.widget<Material>(materialFinder.first);
        expect(materialWidget.color, Colors.white);
        expect(materialWidget.borderRadius, BorderRadius.circular(14));
        expect(materialWidget.clipBehavior, Clip.antiAlias);

        // Assert NO error matches "ListTile background color or ink splashes may be invisible"
        final invisibleInkErrors = errors.where((e) =>
            e.exceptionAsString().contains('ListTile background color or ink splashes may be invisible'));
        expect(invisibleInkErrors, isEmpty);
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  });
}
