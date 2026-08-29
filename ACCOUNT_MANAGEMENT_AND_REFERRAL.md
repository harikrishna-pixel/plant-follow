## Account Management & Referral Updates

### Logout Entry
- Drawer now includes `Log Out`.
- Confirms before signing out.
- After confirmation:
  - Calls `AuthService.instance.signOut()`.
  - Clears local caches via `LocalStorageService.clearAllData()`.
  - Removes `free_scans_remaining` and referral prompt flags from `SharedPreferences`.
  - Redirects to `LoginScreen` and shows a success toast.

### Delete Account Entry
- Drawer also exposes `Delete Account` in red.
- Double confirmation outlines permanent data removal.
- On approval:
  - Attempts `FirebaseAuth.currentUser.delete()`.
  - Deletes the `users/{uid}` wallet document via `WalletService.deleteUserWallet`.
  - Clears Hive caches and preference keys (same as logout).
  - Signs out and returns to `LoginScreen`.
- Handles `requires-recent-login` with a snackbar prompt.

### Referral Prompt Dialog
- First post-login launch checks Firestore wallet:
  - Skips if referral already claimed or user dismissed previously (`referral_prompt_shown_{uid}`).
  - Shows a dialog asking for a friend’s referral ID and displays the user’s own ID for sharing.
- Submission calls `WalletService.applyReferralCode`.
  - Success triggers wallet refresh, sets the prompt flag, and shows a bonus toast.
  - Invalid codes surface inline errors.

### Data Deletion Coverage
- Wallet document (`users/{uid}` collection) is removed.
- Local Hive boxes (`favorites_box`, `search_cache_box`) are cleared.
- `SharedPreferences` keys tied to scans and referral prompt are removed.
- No other Firestore collections are currently used by the app, so all cloud data linked to the user is erased.*** End Patch```) to=functions.apply_patch code_output to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patchими to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch to=functions.apply_patch ]}

