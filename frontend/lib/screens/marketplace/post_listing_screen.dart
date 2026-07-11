import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../models/seller_model.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/dark_text_field.dart';
import '../../widgets/gallery_photo_picker.dart';

class PostListingScreen extends ConsumerStatefulWidget {
  const PostListingScreen({super.key});

  @override
  ConsumerState<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends ConsumerState<PostListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();

  String _category = marketplaceCategories.first;
  String _condition = 'used';
  List<String> _imageUrls = [];
  String? _imageUrlsError;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null) return;
    final formValid = formState.validate();
    final hasImages = _imageUrls.isNotEmpty;
    setState(() =>
        _imageUrlsError = hasImages ? null : 'Add at least one product image');
    if (!formValid || !hasImages) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final success = await ref.read(marketplaceProvider.notifier).createListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          category: _category,
          imageUrls: _imageUrls,
          condition: _condition,
          location: _locationController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(marketplaceProvider).myListingsError ??
            'Could not post your listing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seller = ref.watch(marketplaceProvider.select((s) => s.mySeller));
    final isApproved = seller?.isApproved ?? false;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
            onPressed: () => context.pop()),
        title: const Text('Post a listing',
            style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: isApproved ? _buildForm() : _buildBecomeSellerPrompt(seller),
    );
  }

  Widget _buildBecomeSellerPrompt(SellerModel? seller) {
    final isPending = seller?.isPending ?? false;
    final isRejected = seller?.isRejected ?? false;

    String title;
    String message;
    if (isPending) {
      title = 'Application pending';
      message =
          "Your seller application is still under review. You can post listings once it's approved.";
    } else if (isRejected) {
      title = 'Application rejected';
      message =
          "Your seller application wasn't approved. Contact support if you think this is a mistake.";
    } else {
      title = 'Become a seller first';
      message =
          'You need an approved seller profile before you can post listings on the marketplace.';
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(marketplaceProvider.notifier).loadMySellerProfile(),
      color: DarkPalette.leafGreen,
      backgroundColor: DarkPalette.navyCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined,
                  color: DarkPalette.textMuted, size: 40),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: DarkPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: DarkPalette.textSecondary,
                    fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              if (!isPending)
                CustomButton(
                  label: isRejected ? 'Reapply as a seller' : 'Become a seller',
                  // Same destination either way — the backend has no
                  // separate reapplication endpoint (submitting again while
                  // a rejected profile exists is rejected with 409 "you
                  // already have a seller profile"), so this at least lets
                  // a rejected applicant reach the form and see that real
                  // error via the existing error handling there, instead of
                  // a permanently dead button. A true fix needs a backend
                  // change to allow resubmission after rejection.
                  onPressed: () => context.push('/marketplace/become-seller'),
                ),
            ],
          ),
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
            _label('Title'),
            DarkTextField(
                hint: 'What are you selling?',
                icon: Icons.sell_outlined,
                controller: _titleController,
                validator: _required),
            const SizedBox(height: 14),
            _label('Description'),
            DarkTextField(
                hint: 'Describe the item',
                icon: Icons.notes_rounded,
                controller: _descriptionController),
            const SizedBox(height: 14),
            _label('Price (₹)'),
            DarkTextField(
              hint: '0',
              icon: Icons.currency_rupee,
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Category'),
            _dropdown(_category, marketplaceCategories,
                (v) => setState(() => _category = v ?? _category)),
            const SizedBox(height: 14),
            _label('Condition'),
            _dropdown(
              _condition,
              const ['new', 'used'],
              (v) => setState(() => _condition = v ?? _condition),
              labelBuilder: (v) => v == 'new' ? 'New' : 'Used',
            ),
            const SizedBox(height: 14),
            _label('Location (optional)'),
            DarkTextField(
                hint: 'e.g. Mumbai, Andheri',
                icon: Icons.location_on_outlined,
                controller: _locationController),
            const SizedBox(height: 14),
            _label('Photos'),
            GalleryPhotoPicker(
              urls: _imageUrls,
              onChanged: (urls) => setState(() => _imageUrls = urls),
            ),
            if (_imageUrlsError != null) ...[
              const SizedBox(height: 6),
              Text(_imageUrlsError!,
                  style:
                      const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  style:
                      const TextStyle(color: Color(0xFFE0605A), fontSize: 12)),
            ],
            const SizedBox(height: 24),
            CustomButton(
                label: 'Post listing',
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

  Widget _dropdown(
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    String Function(String)? labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
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
      items: options
          .map((o) => DropdownMenuItem(
              value: o,
              child: Text(labelBuilder != null ? labelBuilder(o) : o)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
