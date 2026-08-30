// Pure rules for apprentice resumes. No Flutter, no Supabase — these are
// shared by the picker (which validates before uploading), the use case, and
// the datasource (which builds the path).

const int kMaxResumeBytes = 5 * 1024 * 1024;
const List<String> kAllowedResumeExtensions = ['pdf', 'doc', 'docx'];

/// Returns null when the file is acceptable, otherwise the user-facing reason.
///
/// Checked before any upload starts: nobody should wait on a network
/// round-trip to be told their file is the wrong type.
String? resumeFileProblem(String fileName, int sizeBytes) {
  const limit = 'PDF, DOC or DOCX up to 5 MB.';
  if (sizeBytes <= 0) return 'That file is empty. $limit';
  if (sizeBytes > kMaxResumeBytes) return 'That file is over 5 MB. $limit';
  if (!kAllowedResumeExtensions.contains(resumeExtension(fileName))) {
    return "That file type isn't supported. $limit";
  }
  return null;
}

/// Lower-cased extension, or the empty string when there isn't one.
String resumeExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

/// `{uid}/resume/{epoch}.{ext}` — the exact shape BOTH storage policies key
/// on: `foldername[1]` is the owner uid, `foldername[2]` is the literal
/// 'resume'. Changing this shape silently breaks builder access, because
/// private_docs_resume_applied_builder_select tests `foldername[2] = 'resume'`.
///
/// The original filename is deliberately NOT used: it routinely contains the
/// person's full name, and storage object keys are far less private than the
/// bytes behind them.
String resumeStoragePath(String userId, String fileName, int epochSeconds) {
  final ext = resumeExtension(fileName);
  final safe = kAllowedResumeExtensions.contains(ext) ? ext : 'pdf';
  return '$userId/resume/$epochSeconds.$safe';
}

/// MIME type for the upload, so the browser and the viewer both do the right
/// thing with the object instead of downloading an octet-stream blob.
String resumeContentType(String fileName) => switch (resumeExtension(
  fileName,
)) {
  'pdf' => 'application/pdf',
  'doc' => 'application/msword',
  'docx' =>
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  _ => 'application/octet-stream',
};
