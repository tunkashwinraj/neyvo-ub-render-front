# Front repo – why "not a git repository" and how to fix it

## What’s going on

- Your current folder is **UB_Neyvo_Front** (capital F). It has your Flutter app but **no** `.git` folder.
- The clone created a **subfolder** named **UB_Neyvo_front** (lowercase f). That subfolder is the real Git repo.

So `git remote -v` and `git push` fail in **UB_Neyvo_Front** because Git only runs inside **UB_Neyvo_front**.

---

## Option 1: Use the cloned folder (simplest)

Run Git commands **inside** the cloned repo:

```powershell
cd "C:\Ashwin Project\UB Neyvo\UB_Neyvo_Front\UB_Neyvo_front"
git remote -v
git push
```

Use this folder when you want to push/pull.

---

## Option 2: Make UB_Neyvo_Front itself the Git repo

If you want to work in **UB_Neyvo_Front** and have **that** folder be the repo (no subfolder):

1. In **UB_Neyvo_Front**, run the script:  
   `.\scripts\init_git_here.ps1`  
   (Script is created for you.)
2. Then use `git push` from **UB_Neyvo_Front** as usual.

See the script for what it does (init, remote, branch, first push).
