**WARNING: Please, read this note carefully before submitting a new pull request:**

Nelua is open source,
but not very open to contributions in the form of pull requests,
if you would like something fixed or implemented in the core language
try first submitting a bug report or opening a discussion instead of doing a PR.
The authors prefer it this way, so that the ideal solution is always provided,
without unwanted consequences on the project, thus keeping the quality of the software.

If you insist doing a PR, typically for a small bug fix, then follow these guidelines:

- Make sure the PR description clearly describes the problem and solution. Include the relevant issue number if applicable.
- Don't send big pull requests (lots of changes), they are difficult to review. It's better to send small pull requests, one at a time.
- Use different pull requests for different issues, each pull request should only address one issue.
- When fixing a bug or adding a feature add tests related to your changes to assure the changes will always work as intended in the future and also to cover new lines added.
- Verify that changes don't break the tests.
- Follow the same coding style rules as the code base.
- Pull requests just doing style changes are not welcome, a PR must address a real issue.

### Motivation

Describe why you or others may need this PR.

### Code example

Provide minimal code example that this PR may allow.

### Tests

Check if all Nelua tests pass, you can check this with `make test`.
If your PR addresses a bug or a new feature,
then make sure to add a test for it in the test suite when possible.
