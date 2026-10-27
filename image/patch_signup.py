"""Close open sign-up on a public deployment.

Upstream's self-hosted login creates an account for any email on first use, which on a
public Railway URL lets any stranger spend the deployer's OpenRouter key and run code in
the sandbox. After the first account exists, new accounts are refused unless the email
has a pending project invite, or OVERMIND_OPEN_SIGNUP=true.
"""
import glob

ANCHOR = "    with transaction.atomic():\n        user = User.objects.create_user(\n"
GUARD = (
    "    import os\n"
    "    from overbae.models import ProjectInvite\n"
    "\n"
    '    if (\n'
    '        os.environ.get("OVERMIND_OPEN_SIGNUP", "").lower() != "true"\n'
    "        and User.objects.filter(is_guest=False).exists()\n"
    "        and not ProjectInvite.objects.filter(email__iexact=email).exists()\n"
    "    ):\n"
    "        raise InvalidCredentials()\n"
    "\n"
)

paths = glob.glob("/code/overbae/api/auth_registration.py") + glob.glob(
    "/code/.venv/lib/python*/site-packages/overbae/api/auth_registration.py"
)
assert paths, "auth_registration.py not found"
for path in paths:
    src = open(path).read()
    assert src.count(ANCHOR) == 1, f"anchor drifted in {path}; re-check local_session upstream"
    open(path, "w").write(src.replace(ANCHOR, GUARD + ANCHOR))
    print("patched", path)
