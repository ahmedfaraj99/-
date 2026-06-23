import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/design_system.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  String? _selectedType;
  String _searchQuery = '';

  // Nearest-to-me
  bool      _sortByNearest = false;
  Position? _userPosition;
  bool      _locating      = false;

  final List<Map<String, dynamic>> _filterTypes = [
    {'type': null, 'label': 'الكل',     'icon': Icons.apps_rounded,           'color': DesignSystem.teal},
    {'type': '0',  'label': 'مستشفى',  'icon': Icons.local_hospital_outlined, 'color': DesignSystem.rose},
    {'type': '3',  'label': 'صيدلية',  'icon': Icons.medication_outlined,     'color': DesignSystem.emerald},
    {'type': '5',  'label': 'مختبر',   'icon': Icons.science_outlined,        'color': DesignSystem.violet},
    {'type': '1',  'label': 'بصريات',  'icon': Icons.visibility_outlined,     'color': DesignSystem.amber},
  ];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getProviders(type: _selectedType);
      if (res['success'] == true && mounted) {
        setState(() {
          _providers = List<Map<String, dynamic>>.from(res['providers'] ?? []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _distanceKm(Map<String, dynamic> p) {
    if (_userPosition == null) return double.maxFinite;
    final lat = double.tryParse(p['latitude']?.toString() ?? '');
    final lng = double.tryParse(p['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return double.maxFinite;
    return Geolocator.distanceBetween(
          _userPosition!.latitude, _userPosition!.longitude, lat, lng) /
        1000;
  }

  String _fmtDistance(double km) {
    if (km >= double.maxFinite) return '';
    if (km < 1) return '${(km * 1000).round()} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  Future<void> _toggleNearestSort() async {
    if (_sortByNearest) {
      setState(() { _sortByNearest = false; _userPosition = null; });
      return;
    }
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) {
        setState(() {
          _userPosition   = pos;
          _sortByNearest  = true;
          _locating       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProviders {
    var list = _providers
        .where((p) => (p['name'] ?? '').toString().contains(_searchQuery))
        .toList();
    if (_sortByNearest && _userPosition != null) {
      list.sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: DesignSystem.bgPrimary,
        bottomNavigationBar: const AppBottomNav(currentIndex: 2),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _buildSearchBar(),
              ),
              SizedBox(
                height: 44,
                child: _buildFilterChips(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DesignSystem.teal, strokeWidth: 2))
                    : _filteredProviders.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: DesignSystem.teal,
                            onRefresh: _loadProviders,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: _filteredProviders.length,
                              itemBuilder: (_, i) =>
                                  _buildProviderCard(_filteredProviders[i], i),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // TOP BAR
  // ───────────────────────────────────────
  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          if (canPop)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: DesignSystem.bgBody,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
                  border: Border.all(color: DesignSystem.borderPrimary),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: DesignSystem.textPrimary, size: 16),
              ),
            )
          else
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: DesignSystem.teal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DesignSystem.radiusIconBtn),
              ),
              child: const Icon(Icons.local_hospital_rounded,
                  color: DesignSystem.teal, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'مزودي الخدمة',
              style: DesignSystem.headingStyle.copyWith(fontSize: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // زر الأقرب لموقعي
          GestureDetector(
            onTap: _locating ? null : _toggleNearestSort,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _sortByNearest
                    ? DesignSystem.teal
                    : DesignSystem.teal.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _locating
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              color: DesignSystem.teal, strokeWidth: 2))
                      : Icon(
                          Icons.near_me_rounded,
                          size: 13,
                          color: _sortByNearest
                              ? Colors.white
                              : DesignSystem.teal,
                        ),
                  const SizedBox(width: 5),
                  Text(
                    'الأقرب',
                    style: DesignSystem.labelStyle.copyWith(
                      color: _sortByNearest
                          ? Colors.white
                          : DesignSystem.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: DesignSystem.teal.withOpacity(0.10),
              borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
            ),
            child: Text(
              '${_providers.length} مزود',
              style: DesignSystem.labelStyle.copyWith(
                color: DesignSystem.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ───────────────────────────────────────
  // SEARCH BAR
  // ───────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: DesignSystem.bgBody,
        borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
        border: Border.all(color: DesignSystem.borderPrimary),
      ),
      child: TextField(
        style: DesignSystem.bodyTextStyle.copyWith(fontSize: 13),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'ابحث باسم مزود الخدمة...',
          hintStyle: DesignSystem.bodyTextStyle.copyWith(
              color: DesignSystem.textSubtle, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: DesignSystem.teal, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ───────────────────────────────────────
  // FILTER CHIPS
  // ───────────────────────────────────────
  Widget _buildFilterChips() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filterTypes.length,
      itemBuilder: (_, i) {
        final f = _filterTypes[i];
        final bool sel = _selectedType == f['type'];
        final color = f['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedType = f['type']);
              _loadProviders();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? color : DesignSystem.bgBody,
                borderRadius: BorderRadius.circular(DesignSystem.radiusPill),
                border: Border.all(
                    color: sel ? color : DesignSystem.borderPrimary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f['icon'] as IconData,
                      size: 14,
                      color: sel ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(
                    f['label'],
                    style: DesignSystem.smallTextStyle.copyWith(
                      color: sel ? Colors.white : DesignSystem.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────
  // PROVIDER CARD — Grid 2×N (مطابق للمقترح)
  // ───────────────────────────────────────
  Widget _buildProviderCard(Map<String, dynamic> p, int i) {
    final type = p['type']?.toString() ?? '';
    final typeColor = _typeColor(type);
    final typeGradient = _typeGradient(type);
    final hasLocation = p['latitude'] != null && p['longitude'] != null;

    return GestureDetector(
      onTap: hasLocation ? () => _openMap(p) : null,
      child: Container(
        decoration: BoxDecoration(
          color: DesignSystem.bgBody,
          borderRadius: BorderRadius.circular(DesignSystem.radiusCard),
          border: Border.all(color: DesignSystem.borderPrimary),
          boxShadow: DesignSystem.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image header (gradient + big icon) ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DesignSystem.radiusCard),
              ),
              child: Container(
                height: 80,
                decoration: BoxDecoration(gradient: typeGradient),
                child: Stack(
                  children: [
                    // Decorative circle
                    Positioned(
                      right: -20, top: -20,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                    ),
                    // Center icon
                    Center(
                      child: Icon(
                        _typeIcon(type),
                        size: 36,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    // Distance badge when sorting by nearest
                    if (hasLocation && _sortByNearest)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Builder(builder: (_) {
                          final km  = _distanceKm(p);
                          final lbl = _fmtDistance(km);
                          final bg  = km < 1
                              ? DesignSystem.emerald
                              : km < 5
                                  ? DesignSystem.teal
                                  : Colors.grey.shade600;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me_rounded,
                                    size: 9, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(lbl,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ],
                            ),
                          );
                        }),
                      )
                    // Map pin badge (if has location, not in nearest mode)
                    else if (hasLocation)
                      Positioned(
                        bottom: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 10, color: typeColor),
                              const SizedBox(width: 2),
                              Text(
                                'الموقع',
                                style: DesignSystem.labelStyle.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p['name'] ?? '',
                            style: DesignSystem.headingStyle.copyWith(
                              fontSize: 12,
                              height: 1.3,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            p['type_text'] ?? 'عام',
                            style: DesignSystem.labelStyle.copyWith(
                              color: DesignSystem.textMuted,
                            ),
                            softWrap: true,
                          ),
                          if (p['avg_rating'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                ...List.generate(5, (si) {
                                  final filled = si <
                                      ((p['avg_rating'] as num).toDouble())
                                          .round();
                                  return Icon(
                                    filled
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: DesignSystem.amber,
                                    size: 12,
                                  );
                                }),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    (p['avg_rating'] as num).toStringAsFixed(1),
                                    style: DesignSystem.labelStyle.copyWith(
                                      color: DesignSystem.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 11,
                            color: hasLocation
                                ? typeColor
                                : DesignSystem.textSubtle,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              hasLocation
                                  ? ((p['address'] ?? 'متاح').toString())
                                  : 'لا يوجد موقع',
                              style: DesignSystem.labelStyle.copyWith(
                                color: hasLocation
                                    ? typeColor
                                    : DesignSystem.textSubtle,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (i * 35).ms, duration: 300.ms)
        .slideY(begin: 0.04, curve: DesignSystem.easeOutCurve);
  }

  // Gradient حسب نوع المزود (مطابق للمقترح)
  LinearGradient _typeGradient(String type) {
    switch (type) {
      case '0': // مستشفى — رمادي/فيروزي
        return const LinearGradient(
          colors: [Color(0xFF99F6E4), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case '3': // صيدلية — أخضر sage
        return const LinearGradient(
          colors: [Color(0xFFD9F99D), Color(0xFF84CC16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case '5': // مختبر — بنفسجي
        return const LinearGradient(
          colors: [Color(0xFFC4B5FD), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case '1': // بصريات — أمبر
        return const LinearGradient(
          colors: [Color(0xFFFCD34D), Color(0xFFEAB308)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF99F6E4), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // ───────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────
  void _openMap(Map<String, dynamic> p) async {
    final lat = p['latitude'];
    final lng = p['longitude'];
    if (lat == null || lng == null) return;

    final name = Uri.encodeComponent((p['name'] ?? '').toString());

    try {
      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {}

    try {
      final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Map launch failed: $e');
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case '0': return DesignSystem.rose;
      case '1': return DesignSystem.amber;
      case '3': return DesignSystem.emerald;
      case '5': return DesignSystem.violet;
      default:  return DesignSystem.teal;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case '0': return Icons.local_hospital_outlined;
      case '1': return Icons.visibility_outlined;
      case '3': return Icons.medication_outlined;
      case '5': return Icons.science_outlined;
      default:  return Icons.medical_services_outlined;
    }
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: DesignSystem.teal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 44, color: DesignSystem.teal),
              ),
              const SizedBox(height: 16),
              Text(
                'لا يوجد مزودين',
                style: DesignSystem.headingStyle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'لا يوجد مزودين يطابقون بحثك'
                    : 'لا يوجد مزودين في هذه الفئة',
                textAlign: TextAlign.center,
                style: DesignSystem.smallTextStyle.copyWith(
                  color: DesignSystem.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
}
