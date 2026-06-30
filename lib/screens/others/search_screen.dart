import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:oneshot/models/prime_content.dart';
import 'package:oneshot/providers/auth_provider.dart';
import 'package:oneshot/providers/search_provider.dart';
import 'package:oneshot/theme/app_theme.dart';

import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _executeSearch() async {
    final user = context.read<AppAuthProvider>().currentUser;
    if (user == null) return;

    await context.read<SearchProvider>().search(
      viewerId: user.uid,
      query: _searchController.text,
      subscribedOnly: context.read<SearchProvider>().subscribedOnly,
    );
  }

  Future<void> _toggleSubscribedOnly(bool value) async {
    final user = context.read<AppAuthProvider>().currentUser;
    if (user == null) return;

    await context.read<SearchProvider>().search(
      viewerId: user.uid,
      query: _searchController.text,
      subscribedOnly: value,
    );
  }

  void _openProfile(AuthorProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(authorId: profile.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();

    return Scaffold(
      backgroundColor: kBg,
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Show only subscribed',
                  style: TextStyle(color: kTextSecondary),
                ),
                const Spacer(),
                Switch(
                  value: searchProvider.subscribedOnly,
                  onChanged: _toggleSubscribedOnly,
                  activeThumbColor: kAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: searchProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kAccent),
                    )
                  : searchProvider.results.isEmpty
                  ? _buildEmptyState(searchProvider.subscribedOnly)
                  : ListView.builder(
                      itemCount: searchProvider.results.length,
                      itemBuilder: (context, index) {
                        final profile = searchProvider.results[index];
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

  Widget _buildEmptyState(bool subscribedOnly) {
    final String message = subscribedOnly
        ? 'No subscribed authors found'
        : 'No Results Found';
    final String hint = subscribedOnly
        ? 'Toggle off to search all authors.'
        : 'Enter an exact handle or displayName prefix to query.';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(hint, style: const TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }
}
