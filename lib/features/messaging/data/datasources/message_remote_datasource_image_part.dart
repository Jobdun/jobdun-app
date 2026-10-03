part of 'message_remote_datasource.dart';

mixin _ImageUploadRemote {
  SupabaseClient get _client;

  Future<void> _uploadImmutableImage(
    String path,
    File file,
    String mime,
  ) async {
    final storage = _client.storage.from('chat-attachments');
    try {
      // The bucket grants INSERT/SELECT, deliberately not UPDATE. Retries must
      // never overwrite an attachment that an existing message references.
      await storage.upload(
        path,
        file,
        fileOptions: FileOptions(contentType: mime),
      );
    } on StorageException catch (error) {
      const duplicates = {
        'ResourceAlreadyExists',
        'KeyAlreadyExists',
        'Duplicate',
      };
      if (error.statusCode != '409' || !duplicates.contains(error.error)) {
        rethrow;
      }
      // A path collision alone does not prove this is our previous upload.
      // Authenticated download enforces participant RLS; compare exact bytes.
      final existing = await storage.download(path);
      final intended = await file.readAsBytes();
      if (existing.length != intended.length) rethrow;
      for (var i = 0; i < existing.length; i++) {
        if (existing[i] != intended[i]) rethrow;
      }
    }
  }
}
