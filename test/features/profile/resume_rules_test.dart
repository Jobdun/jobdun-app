import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/resume_rules.dart';

void main() {
  group('resumeFileProblem', () {
    test('accepts pdf, doc and docx regardless of case', () {
      for (final name in ['cv.pdf', 'CV.PDF', 'a.doc', 'a.DOCX']) {
        expect(resumeFileProblem(name, 1024), isNull, reason: name);
      }
    });

    test('rejects other extensions, naming what IS allowed', () {
      final err = resumeFileProblem('resume.pages', 1024);
      expect(err, isNotNull);
      expect(err, contains('PDF'));
      expect(err, contains('5 MB'));
    });

    test('rejects a file with no extension at all', () {
      expect(resumeFileProblem('resume', 1024), isNotNull);
    });

    test('rejects over 5 MB but accepts exactly 5 MB', () {
      expect(resumeFileProblem('cv.pdf', kMaxResumeBytes + 1), isNotNull);
      expect(resumeFileProblem('cv.pdf', kMaxResumeBytes), isNull);
    });

    test('rejects an empty file', () {
      expect(resumeFileProblem('cv.pdf', 0), isNotNull);
      expect(resumeFileProblem('cv.pdf', -1), isNotNull);
    });
  });

  group('resumeStoragePath', () {
    test('builds the shape both storage policies key on', () {
      final path = resumeStoragePath('user-123', 'My CV.pdf', 1756600000);
      expect(path, 'user-123/resume/1756600000.pdf');
      final parts = path.split('/');
      expect(parts[0], 'user-123', reason: 'foldername[1] = owner uid');
      expect(parts[1], 'resume', reason: "foldername[2] = literal 'resume'");
    });

    test('lower-cases the extension and falls back to pdf', () {
      expect(resumeStoragePath('u', 'CV.PDF', 1), 'u/resume/1.pdf');
      expect(resumeStoragePath('u', 'noextension', 1), 'u/resume/1.pdf');
      expect(resumeStoragePath('u', 'cv.exe', 1), 'u/resume/1.pdf');
    });

    test('drops the original filename, which usually carries a real name', () {
      final path = resumeStoragePath('u', 'Ken Garcia Resume 2026.pdf', 42);
      expect(path, isNot(contains('Ken')));
      expect(path, isNot(contains('Garcia')));
      expect(path, 'u/resume/42.pdf');
    });

    test('preserves doc and docx', () {
      expect(resumeStoragePath('u', 'a.doc', 1), 'u/resume/1.doc');
      expect(resumeStoragePath('u', 'a.docx', 1), 'u/resume/1.docx');
    });
  });

  group('resumeContentType', () {
    test('maps each allowed type', () {
      expect(resumeContentType('a.pdf'), 'application/pdf');
      expect(resumeContentType('a.doc'), 'application/msword');
      expect(resumeContentType('a.docx'), contains('wordprocessingml'));
    });

    test('falls back for anything else', () {
      expect(resumeContentType('a.zip'), 'application/octet-stream');
    });
  });
}
