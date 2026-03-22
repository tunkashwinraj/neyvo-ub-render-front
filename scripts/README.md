# Scripts (frontend repo)

## `push_and_test_messaging_defaults`

These files **forward** to the real script in **`GU_Neyvo_Back/scripts/`** so you can run from `GU_Neyvo_Front` without changing directory.

**Prerequisite:** `GU_Neyvo_Back` and `GU_Neyvo_Front` must share the same parent folder (e.g. `Neyvo_GU`).

```powershell
cd C:\projects\Neyvo_GU\GU_Neyvo_Front

$env:NEYVO_ACCOUNT_ID = "757763"
$env:NEYVO_OPERATOR_ID = "YOUR_OPERATOR_ID"

python scripts/push_and_test_messaging_defaults.py --dry-run
python scripts/push_and_test_messaging_defaults.py --base-url https://neyvoub-back.onrender.com --crud-only
```

Or:

```powershell
.\scripts\push_and_test_messaging_defaults.ps1 -BaseUrl "https://neyvoub-back.onrender.com" -CrudOnly
```

Full docs: `GU_Neyvo_Back/scripts/README_MESSAGING_DEFAULTS_TEST.md`
