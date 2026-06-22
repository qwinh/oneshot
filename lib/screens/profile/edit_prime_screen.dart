import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/prime_content.dart';
import '../../services/content_service.dart';
import '../../services/storage_service.dart';

class EditPrimeScreen extends StatefulWidget {
  const EditPrimeScreen({super.key});

  @override
  State<EditPrimeScreen> createState() => _EditPrimeScreenState();
}

class _EditPrimeScreenState extends State<EditPrimeScreen> {
  final ContentService _contentService = ContentService();
  final StorageService _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  PrimeContentType _contentType = PrimeContentType.text;
  List<PrimeImage> _images = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  // State preservation to prevent overwriting original creation date
  DateTime? _existingCreatedAt;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _nameController.dispose();
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await _contentService.getProfile(user.uid);
      if (profile != null) {
        _handleController.text = profile.handle;
        _nameController.text = profile.displayName;
        _contentType = profile.primeContentType;
        _textController.text = profile.textPayload ?? '';
        _images = List.from(profile.images);
        _tagsController.text = profile.tags.join(', ');
        // Safely cache original document creation date
        _existingCreatedAt = profile.createdAt;
      }
    } catch (e) {
      _errorMessage = 'Failed to load profile data.';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Simulation utility that generates a solid block color JPG/PNG representation to
  /// test Firebase Storage upload rules instantly without needing an external File Picker package.
  Future<void> _simulateImageUpload() async {
    if (_images.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scarcity rule: Maximum 4 discovery images allowed.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Generate an interactive mock byte structure representing an image (1x1 transparent/color png)
      final Uint8List mockImageBytes = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        204,
        137,
        0,
        0,
        0,
        13,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        96,
        0,
        1,
        0,
        0,
        5,
        0,
        1,
        13,
        10,
        45,
        180,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ]);

      final String fileId = 'mock_${DateTime.now().millisecondsSinceEpoch}.png';

      // 2. Real transmission to cloud storage bucket
      final String uploadedUrl = await _storageService.uploadPrimeImage(
        authorId: user.uid,
        fileName: fileId,
        bytes: mockImageBytes,
      );

      setState(() {
        _images.add(
          PrimeImage(url: uploadedUrl, name: 'Image ${_images.length + 1}'),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mock upload failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _removeUploadedImage(int index) async {
    final String url = _images[index].url;
    setState(() {
      _images.removeAt(index);
    });
    // Fire-and-forget deletion from active bucket
    await _storageService.deleteImageByUrl(url);
  }

  /// REQ-FUNC-003: each image in the set has an associated name.
  void _renameImage(int index, String newName) {
    setState(() {
      _images[index] = _images[index].copyWith(name: newName);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentType == PrimeContentType.imageSet && _images.isEmpty) {
      setState(() => _errorMessage = 'Please upload at least one image.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    // Normalize comma separated tags safely
    final List<String> parsedTags = _tagsController.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    final profile = AuthorProfile(
      uid: user.uid,
      handle: _handleController.text.trim(),
      displayName: _nameController.text.trim(),
      primeContentType: _contentType,
      textPayload: _contentType == PrimeContentType.text
          ? _textController.text.trim()
          : null,
      images: _contentType == PrimeContentType.imageSet ? _images : [],
      tags: parsedTags,
      hidden: false,
      // Preserves original creation date, fall back to now only if first-time save
      createdAt: _existingCreatedAt ?? DateTime.now(),
    );

    try {
      await _contentService.saveAuthorProfile(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prime profile successfully published!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Discovery Prime'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Profile identity section
                    TextFormField(
                      controller: _handleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Unique Author Handle (e.g., johndoe)',
                        prefixText: '@ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Handle is required';
                        if (val.contains(' '))
                          return 'Handle cannot contain spaces';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty)
                          return 'Display Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Scarcity Content Type selector
                    const Text(
                      'Prime Discovery Content Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Text Post / Link'),
                            selected: _contentType == PrimeContentType.text,
                            onSelected: (selected) {
                              if (selected)
                                setState(
                                  () => _contentType = PrimeContentType.text,
                                );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Image Set (1-4)'),
                            selected: _contentType == PrimeContentType.imageSet,
                            onSelected: (selected) {
                              if (selected)
                                setState(
                                  () =>
                                      _contentType = PrimeContentType.imageSet,
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form bodies conditional on selection
                    if (_contentType == PrimeContentType.text) ...[
                      TextFormField(
                        controller: _textController,
                        maxLines: 8,
                        maxLength: 1000,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText:
                              'Write your prime text or insert discovery link...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (_contentType == PrimeContentType.text &&
                              (val == null || val.isEmpty)) {
                            return 'Content body cannot be blank';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Prime Image Gallery (${_images.length}/4)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_isUploading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else if (_images.length < 4)
                                  TextButton.icon(
                                    onPressed: _simulateImageUpload,
                                    icon: const Icon(
                                      Icons.add_photo_alternate,
                                      size: 18,
                                    ),
                                    label: const Text('Simulate Upload'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_images.isEmpty)
                              const Text(
                                'No images uploaded yet. Simulating adds a sample asset to cloud storage.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.85,
                                    ),
                                itemCount: _images.length,
                                itemBuilder: (context, idx) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  _images[idx].url,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          color: Colors
                                                              .blueGrey[800],
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                            color:
                                                                Colors.white,
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: CircleAvatar(
                                                radius: 14,
                                                backgroundColor: Colors.black
                                                    .withOpacity(0.7),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                  onPressed: () =>
                                                      _removeUploadedImage(
                                                        idx,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // REQ-FUNC-003: each image carries an associated name.
                                      TextFormField(
                                        key: ValueKey(
                                          'image_name_${idx}_${_images[idx].url}',
                                        ),
                                        initialValue: _images[idx].name,
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          hintText: 'Image name',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        onChanged: (val) =>
                                            _renameImage(idx, val),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Categorization Tags
                    TextFormField(
                      controller: _tagsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText:
                            'Tags (comma separated, e.g., poetry, sci-fi, photography)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save Action Row
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Publish Prime Content',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
