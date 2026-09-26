import 'package:flutter_test/flutter_test.dart';
import 'package:uem_eats/models/profile_model.dart';
import 'package:uem_eats/models/vendor_model.dart';
import 'package:uem_eats/models/menu_item_model.dart';
import 'package:uem_eats/models/order_model.dart';
import 'package:uem_eats/providers/cart_provider.dart';
import 'package:uem_eats/core/utils/currency_formatter.dart';
import 'package:uem_eats/core/constants/app_constants.dart';

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
    });
  });

  group('Formatters Test', () {
    test('CurrencyFormatter produces correct INR format', () {
      expect(CurrencyFormatter.format(154.0), contains('154'));
      expect(CurrencyFormatter.format(null), '₹0.00');
    });
  });
}
