import 'package:flutter/material.dart';
import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/services/discovery_service.dart';
import 'package:oneshot/theme/app_theme.dart';
import '../profile/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final TextEditingController _searchController = TextEditingController();

  List<AuthorProfile> _results = [];
  bool _isLoading = false;

  Future<void> _executeSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final list = await _discoveryService.searchAuthors(query);
      setState(() => _results = list);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openProfile(AuthorProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: profile.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Search Authors'),
        backgroundColor: kBg,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: kTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search handle or display name...',
                      hintStyle: kSubtitleText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) => _executeSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _executeSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTextPrimary,
                    foregroundColor: kBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kAccent),
                    )
                  : _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final profile = _results[index];
                        return Card(
                          color: kSurface,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: kBorder),
                          ),
                          child: ListTile(
                            title: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '@${profile.handle}',
                              style: kSubtitleText,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.white30,
                            ),
                            onTap: () => _openProfile(profile),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter an exact handle or displayName prefix to query.',
            style: TextStyle(color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}
