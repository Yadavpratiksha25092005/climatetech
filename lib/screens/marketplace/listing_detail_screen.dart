import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/listing_model.dart';
import '../../providers/marketplace_provider.dart';

/// Listings at or above this price show a purely informational "EMI
/// available" note — no calculation or actual EMI processing, just a nudge
/// to negotiate financing directly with the seller.
const double _emiEligiblePrice = 3000;

/// Normalizes a raw phone number into the exact digits-only shape wa.me
/// needs: no "+", no spaces/dashes, and a leading country code. A bare
/// 10-digit number is assumed to be Indian and gets "91" prepended; anything
/// else is assumed to already include a country code, so it's left as-is
/// (after stripping non-digit characters) rather than risk double-prefixing.
String waPhoneDigits(String rawPhone) {
  final digitsOnly = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length == 10) {
    return '91$digitsOnly';
  }
  return digitsOnly;
}

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _loading = true;
  String? _error;
  ListingDetailModel? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(marketplaceServiceProvider)
          .getListingDetail(widget.listingId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _launch(Uri uri, String failureFallback) async {
    bool launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureFallback)));
    }
  }

  Future<void> _call() async {
    final phone = _detail?.contactPhone;
    if (phone == null || phone.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: phone),
        'Could not open the dialer. Contact: $phone');
  }

  Future<void> _whatsApp() async {
    final phone = _detail?.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final waNumber = waPhoneDigits(phone);
    if (waNumber.isEmpty) {
      // The raw phone had non-digit characters only (e.g. a garbage value
      // like "N/A") — contactPhone.isEmpty already gates the button for a
      // genuinely empty phone, but this can still slip past that check.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This seller's phone number looks invalid.")),
        );
      }
      return;
    }
    await _launch(Uri.parse('https://wa.me/$waNumber'),
        'Could not open WhatsApp. Contact: $phone');
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
        title: const Text('Listing',
            style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          // _detail == null is included alongside _error != null so a
          // future change to the load/error state machine can't leave this
          // branch reachable with nothing to render — falls back to the
          // same error state (with its own retry button) instead of
          // crashing on a forced unwrap.
          : (_error != null || _detail == null)
              ? _buildErrorState()
              : _buildContent(_detail!),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load this listing.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: DarkPalette.leafGreen,
                  foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ListingDetailModel detail) {
    final listing = detail.listing;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (listing.imageUrls.isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: listing.imageUrls.length,
                itemBuilder: (context, i) => Container(
                  color: DarkPalette.navyCard,
                  alignment: Alignment.center,
                  child: Image.network(
                    listing.imageUrls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withOpacity(0.04),
                      child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: DarkPalette.textMuted)),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.white.withOpacity(0.04),
              child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: DarkPalette.textMuted, size: 40)),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${listing.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: DarkPalette.leafGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w700),
                ),
                if (listing.price >= _emiEligiblePrice) ...[
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.credit_card_outlined,
                          size: 13, color: DarkPalette.textSecondary),
                      SizedBox(width: 5),
                      Text(
                        'EMI available — contact seller for details',
                        style: TextStyle(
                            color: DarkPalette.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(listing.title,
                    style: const TextStyle(
                        color: DarkPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _tag(listing.condition == 'new' ? 'New' : 'Used'),
                    if (listing.location.isNotEmpty) _tag(listing.location),
                    _tag(listing.category),
                  ],
                ),
                const SizedBox(height: 16),
                if (listing.description.isNotEmpty) ...[
                  const Text('Description',
                      style: TextStyle(
                          color: DarkPalette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(listing.description,
                      style: const TextStyle(
                          color: DarkPalette.textSecondary,
                          fontSize: 13,
                          height: 1.5)),
                  const SizedBox(height: 20),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: DarkPalette.leafGreen.withOpacity(0.15),
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            detail.shopName.isNotEmpty
                                ? detail.shopName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: DarkPalette.leafGreen,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    detail.shopName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: DarkPalette.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (detail.verified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.verified,
                                        color: DarkPalette.cyanAccent,
                                        size: 14),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(detail.city,
                                style: const TextStyle(
                                    color: DarkPalette.textMuted,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: detail.contactPhone.isEmpty ? null : _call,
                        icon: Icon(Icons.call_outlined,
                            color: detail.contactPhone.isEmpty
                                ? DarkPalette.textMuted
                                : Colors.black),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkPalette.leafGreen,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.06),
                          disabledForegroundColor: DarkPalette.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            detail.contactPhone.isEmpty ? null : _whatsApp,
                        icon: Icon(Icons.chat_outlined,
                            color: detail.contactPhone.isEmpty
                                ? DarkPalette.textMuted
                                : Colors.black),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkPalette.cyanAccent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.06),
                          disabledForegroundColor: DarkPalette.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              const TextStyle(color: DarkPalette.textSecondary, fontSize: 11)),
    );
  }
}
