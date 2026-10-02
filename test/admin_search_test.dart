import 'package:flutter_test/flutter_test.dart';
import 'package:rakta_bandhan/services/admin_search.dart';

void main() {
  test('admin search selects an indexed prefix or exact private lookup', () {
    expect(adminDonorSearch(' PRIYA '), (field: 'name_lower', value: 'priya', prefix: true));
    expect(adminDonorSearch('@Priya'), (field: 'username', value: 'priya', prefix: true));
    expect(adminDonorSearch('A@Example.com'), (field: 'email', value: 'a@example.com', prefix: false));
    expect(adminDonorSearch('+91 98765 43210'), (field: 'phone', value: '9876543210', prefix: false));
    expect(adminDonorSearch('9198765432').value, '9198765432');
  });
}
