import 'package:flutter_test/flutter_test.dart';
import 'package:uem_eats/models/profile_model.dart';
import 'package:uem_eats/models/vendor_model.dart';
import 'package:uem_eats/models/menu_item_model.dart';
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
