/// ─────────────────────────────────────────────────────────────────────────────
/// LocationPickerWidget — Searchable country/state/city picker with API data
/// ─────────────────────────────────────────────────────────────────────────────
/// Uses LocationService API. Shows searchable bottom sheet dialogs.
/// Cascading: select country → loads states → select state → loads cities
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../config/theme.dart';

class LocationPickerWidget extends StatefulWidget {
  final String? initialCountry;
  final String? initialState;
  final String? initialCity;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onCityChanged;

  const LocationPickerWidget({
    super.key,
    this.initialCountry,
    this.initialState,
    this.initialCity,
    required this.onCountryChanged,
    required this.onStateChanged,
    required this.onCityChanged,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  final _locationService = LocationService();

  String? _country;
  String? _state;
  String? _city;

  List<String> _countries = [];
  List<String> _states = [];
  List<String> _cities = [];

  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry ?? 'Pakistan';
    _state = widget.initialState;
    _city = widget.initialCity;
    _loadCountries();
    // Auto-load states for Pakistan immediately
    if (_country != null) {
      _loadStates(_country!);
      // Defer callback to after build completes to avoid "markNeedsBuild during build" error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCountryChanged(_country);
      });
    }
  }

  @override
  void didUpdateWidget(LocationPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCountry != oldWidget.initialCountry ||
        widget.initialState != oldWidget.initialState ||
        widget.initialCity != oldWidget.initialCity) {
      setState(() {
        _country = widget.initialCountry ?? 'Pakistan';
        _state = widget.initialState;
        _city = widget.initialCity;
      });
      // Reload states if country changed via GPS
      if (widget.initialCountry != oldWidget.initialCountry && _country != null) {
        _loadStates(_country!);
      }
    }
  }

  Future<void> _loadCountries() async {
    final data = await _locationService.getCountries();
    if (mounted) setState(() { _countries = data; _loadingCountries = false; });
  }

  Future<void> _loadStates(String country) async {
    setState(() { _loadingStates = true; _states = []; _cities = []; });
    final data = await _locationService.getStates(country);
    if (mounted) setState(() { _states = data; _loadingStates = false; });
  }

  Future<void> _loadCities(String country, String state) async {
    setState(() { _loadingCities = true; _cities = []; });
    final data = await _locationService.getCities(country, state);
    if (mounted) setState(() { _cities = data; _loadingCities = false; });
  }

  // ── Show searchable bottom sheet ────────────────────────────────────────
  Future<String?> _showSearchSheet(String title, List<String> items) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchSheet(title: title, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Country picker
        _buildPickerTile(
          label: 'Country',
          value: _country,
          icon: Icons.public_outlined,
          isLoading: _loadingCountries,
          hint: _loadingCountries ? 'Loading countries...' : 'Tap to select country',
          isDark: isDark,
          onTap: () async {
            if (_countries.isEmpty) return;
            final result = await _showSearchSheet('Select Country', _countries);
            if (result != null && result != _country) {
              setState(() { _country = result; _state = null; _city = null; _states = []; _cities = []; });
              widget.onCountryChanged(result);
              widget.onStateChanged(null);
              widget.onCityChanged(null);
              _loadStates(result);
            }
          },
        ),
        const SizedBox(height: 14),

        // State picker
        _buildPickerTile(
          label: 'State / Province',
          value: _state,
          icon: Icons.map_outlined,
          isLoading: _loadingStates,
          hint: _country == null
              ? 'Select country first'
              : (_loadingStates ? 'Loading states...' : (_states.isEmpty ? 'No data — type below' : 'Tap to select state')),
          isDark: isDark,
          enabled: _country != null,
          onTap: () async {
            if (_states.isEmpty || _country == null) return;
            final result = await _showSearchSheet('Select State / Province', _states);
            if (result != null && result != _state) {
              setState(() { _state = result; _city = null; _cities = []; });
              widget.onStateChanged(result);
              widget.onCityChanged(null);
              _loadCities(_country!, result);
            }
          },
        ),
        const SizedBox(height: 14),

        // City picker — tap to search or type freely
        _buildPickerTile(
          label: 'City',
          value: _city,
          icon: Icons.location_city_outlined,
          isLoading: _loadingCities,
          hint: _state == null
              ? 'Select state first'
              : (_loadingCities ? 'Loading cities...' : (_cities.isEmpty ? 'No data — type below' : 'Tap to select city')),
          isDark: isDark,
          enabled: _state != null,
          onTap: () async {
            if (_cities.isEmpty) {
              // Allow free-text input if no cities in API
              final result = await _showFreeTextDialog('Enter City');
              if (result != null && result.isNotEmpty) {
                setState(() => _city = result);
                widget.onCityChanged(result);
              }
              return;
            }
            final result = await _showSearchSheet('Select City', _cities);
            if (result != null) {
              setState(() => _city = result);
              widget.onCityChanged(result);
            }
          },
        ),

        // Free text city input (always available as fallback)
        if (_state != null && _cities.isEmpty && !_loadingCities) ...[
          const SizedBox(height: 10),
          TextFormField(
            initialValue: _city,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Type your city',
              hintText: 'Enter city name',
              prefixIcon: const Icon(Icons.edit_location_outlined),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            onChanged: (v) {
              _city = v.trim();
              widget.onCityChanged(v.trim().isEmpty ? null : v.trim());
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPickerTile({
    required String label, required String? value, required IconData icon,
    required bool isLoading, required String hint, required bool isDark,
    required VoidCallback onTap, bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled && !isLoading ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: value != null
                ? AppTheme.primaryRed.withValues(alpha: 0.4)
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value != null ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                      color: value != null ? null : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else if (enabled)
              Icon(Icons.arrow_drop_down_rounded, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
          ],
        ),
      ),
    );
  }

  Future<String?> _showFreeTextDialog(String title) async {
    String text = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => text = v,
          decoration: const InputDecoration(hintText: 'Type city name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, text), child: const Text('OK')),
        ],
      ),
    );
  }
}

/// ── Searchable bottom sheet ───────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  const _SearchSheet({required this.title, required this.items});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((i) => i.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('No results found', style: TextStyle(
                    color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_filtered[i], style: const TextStyle(fontSize: 15)),
                      onTap: () => Navigator.pop(context, _filtered[i]),
                      dense: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
