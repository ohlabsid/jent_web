import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/l10n/app_localizations.dart';
import 'package:jent_web/data/datasources/notes_remote_datasource.dart';
import 'package:jent_web/domain/entities/note_item.dart';
import 'package:jent_web/features/notes/bloc/notes_bloc.dart';
import 'package:jent_web/features/notes/bloc/notes_event.dart';
import 'package:jent_web/features/notes/view/notes_overlay.dart';
import 'package:jent_web/features/notes/view/notes_pin_overlay.dart';
import 'package:mocktail/mocktail.dart';


/// The expanding multiline editor (the search field is single-line).
Finder editorField() => find.byWidgetPredicate(
      (w) => w is TextField && w.expands,
    );

/// Records every write instead of hitting the network, so the
/// debounced save can be asserted offline.
class _RecordingNotesRemote extends Mock implements NotesRemoteDataSource {}

/// Needed by mocktail's `any()` for the [NoteItem] argument.
final _dummyNote = NoteItem(
  id: 'dummy',
  folder: 'notes',
  body: '',
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() => registerFallbackValue(_dummyNote));

  Future<NotesBloc> pumpNotes(
    WidgetTester tester, [
    NotesRemoteDataSource? remote,
  ]) async {
    final bloc = NotesBloc(remote ?? NotesRemoteDataSource());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            body: Stack(
              children: [NotesOverlay(), NotesPinOverlay()],
            ),
          ),
        ),
      ),
    );
    return bloc;
  }

  Future<void> unlockNotes(WidgetTester tester, NotesBloc bloc) async {
    bloc.add(ToggleNotesWindow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('window opens with folders, list, and editor', (tester) async {
    final bloc = await pumpNotes(tester);

    await unlockNotes(tester, bloc);

    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Welcome to Notes'), findsOneWidget);
    expect(editorField(), findsOneWidget);
    expect(bloc.state.isNotesLocked, isFalse);
    // Owner can file notes into General for wrong-PIN guests.
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('creating a note and typing updates the list', (tester) async {
    final bloc = await pumpNotes(tester);

    await unlockNotes(tester, bloc);

    await tester.tap(find.byTooltip('New Note'));
    await tester.pump();

    await tester.enterText(editorField(), 'Grocery run\nbuy oat milk');
    await tester.pump();
    expect(find.text('Grocery run'), findsOneWidget);
    expect(bloc.state.selectedNoteId.isNotEmpty, isTrue);

    // Let the debounced remote save fire (offline no-op in tests).
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a new general note and its body are written to the remote',
      (tester) async {
    final remote = _RecordingNotesRemote();
    final saved = <NoteItem>[];
    when(() => remote.saveNote(any())).thenAnswer((invocation) async {
      saved.add(invocation.positionalArguments.first as NoteItem);
      return true;
    });
    when(() => remote.fetchNotes()).thenAnswer((_) async => null);

    final bloc = await pumpNotes(tester, remote);
    await unlockNotes(tester, bloc);

    // Owner files the note into General (what wrong-PIN guests read).
    await tester.tap(find.text('General'));
    await tester.pump();
    await tester.tap(find.byTooltip('New Note'));
    await tester.pump();

    // Create syncs immediately, even before any text is typed.
    expect(saved, hasLength(1));
    expect(saved.single.folder, 'general');
    final createdId = saved.single.id;

    await tester.enterText(editorField(), 'Grocery run\nbuy oat milk');
    await tester.pump();

    // Typing is debounced, so nothing is written yet.
    expect(saved, hasLength(1));

    await tester.pump(const Duration(seconds: 1));

    final bodyWrite = saved.lastWhere((n) => n.id == createdId);
    expect(bodyWrite.body, 'Grocery run\nbuy oat milk');
  });

  testWidgets('window can be resized from the right edge', (tester) async {    await unlockNotes(tester, await pumpNotes(tester));

    Size windowSize() => tester.getSize(find.byType(AnimatedContainer).first);
    expect(windowSize(), const Size(720, 480));

    await tester.drag(
      find.byKey(const ValueKey('notes-resize-right')),
      const Offset(40, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(windowSize(), const Size(760, 480));
  });

  testWidgets('wrong PIN offers read-only general notes', (tester) async {
    final bloc = await pumpNotes(tester);

    bloc.add(ToggleNotesWindow());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(find.text('View general notes'), findsOneWidget);

    await tester.tap(find.text('View general notes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Guest sees the owner's general note, stays locked.
    expect(bloc.state.isShowNotesWindow, isTrue);
    expect(bloc.state.isNotesLocked, isTrue);
    expect(bloc.state.isNotesGeneralMode, isTrue);
    expect(find.text('Welcome!'), findsOneWidget);
    // Private notes stay hidden.
    expect(find.text('Welcome to Notes'), findsNothing);
    // No edit actions for guests, editor is read-only.
    expect(find.byTooltip('New Note'), findsNothing);
    final editor = tester.widget<TextField>(editorField());
    expect(editor.readOnly, isTrue);
  });
}
