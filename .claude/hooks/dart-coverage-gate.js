#!/usr/bin/env node
// .claude/hooks/dart-coverage-gate.js
//
// PostToolUse hook — fires after Write or Edit tool.
// If a production Dart file was written or modified, directs Claude to run
// test-scout before marking the task complete.
//
// Excluded: *_test.dart, *.g.dart, *.freezed.dart, files under test/

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  let data;
  try {
    data = JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    process.exit(0);
  }

  const filePath = (data.tool_input && data.tool_input.file_path) || '';
  const verb = data.tool_name === 'Edit' ? 'modified' : 'written';

  const normalize = p => p.replace(/\\/g, '/');
  const fp = normalize(filePath);

  const isDart       = fp.endsWith('.dart');
  const isAppLib     = /\/app\/lib\//.test(fp);
  const isTestFile   = fp.endsWith('_test.dart');
  const isGenerated  = fp.endsWith('.g.dart') || fp.endsWith('.freezed.dart');
  const isInTestDir  = /\/app\/test\//.test(fp);

  if (isDart && isAppLib && !isTestFile && !isGenerated && !isInTestDir) {
    const short = fp.replace(/.*\/app\/lib\//, 'lib/');
    process.stdout.write(
      `[coverage-gate] Production Dart file ${verb}: ${short}\n` +
      `Before marking this task complete, spawn the test-scout agent ` +
      `(subagent_type: "test-scout") to verify ${short} has adequate test coverage.\n`
    );
  }

  process.exit(0);
});
