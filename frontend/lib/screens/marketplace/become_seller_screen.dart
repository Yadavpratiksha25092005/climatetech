import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';

class BecomeSellerScreen extends ConsumerStatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  ConsumerState<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends ConsumerState<BecomeSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = marketplaceCategories.first;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await ref.read(marketplaceProvider.notifier).applyAsSeller(
          shopName: _shopNameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          shopCategory: _category,
          phone: _phoneController.text.trim(),
          description: _descriptionController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(marketplaceProvider).sellerError ??
            'Could not submit your application.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
            onPressed: () => context.pop()),
        title: const Text('Become a seller',
            style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _submitted ? _buildSubmittedState() : _buildForm(),
    );
  }

  Widget _buildSubmittedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: DarkPalette.leafGreen.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: DarkPalette.leafGreen, size: 32),
            ),
            const SizedBox(height: 20),
            const Text('Application submitted',
                style: TextStyle(
                    color: DarkPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              "Your seller application is pending review. We'll let you know once it's approved.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: DarkPalette.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            CustomButton(
                label: 'Back to marketplace', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us about your shop. Every application is reviewed before you can post listings.',
              style: TextStyle(
                  color: DarkPalette.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            _label('Shop name'),
            DarkTextField(
                hint: 'e.g. Green Basket Store',
                icon: Icons.storefront_outlined,
                controller: _shopNameController,
                validator: _required),
            const SizedBox(height: 14),
            _label('Owner name'),
            DarkTextField(
                hint: 'Your full name',
                icon: Icons.person_outline,
                controller: _ownerNameController,
                validator: _required),
            const SizedBox(height: 14),
            _label('Address'),
            DarkTextField(
                hint: 'Shop address',
                icon: Icons.location_on_outlined,
                controller: _addressController,
                validator: _required),
            const SizedBox(height: 14),
            _label('City'),
            DarkTextField(
                hint: 'City',
                icon: Icons.location_city_outlined,
                controller: _cityController,
                validator: _required),
            const SizedBox(height: 14),
            _label('Phone number'),
            DarkTextField(
              hint: 'e.g. 98765 43210',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: _required,
            ),
            const SizedBox(height: 14),
            _label('Category'),
            _categoryDropdown(),
            const SizedBox(height: 14),
            _label('Description (optional)'),
            DarkTextField(
                hint: 'What do you sell?',
                icon: Icons.notes_rounded,
                controller: _descriptionController),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style:
                      const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
            ],
            const SizedBox(height: 24),
            CustomButton(
                label: 'Submit application',
                isLoading: _submitting,
                onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: DarkPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      dropdownColor: DarkPalette.navyCard,
      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
      items: marketplaceCategories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => _category = v ?? _category),
    );
  }
}
