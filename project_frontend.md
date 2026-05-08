# Frontend UI Specification

---

## Role Structure

| Role | How Assigned | What They Can Do |
|---|---|---|
| **Chief** | Manually in Supabase by you (developer) | Full access, assign SuperAdmin role, everything |
| **SuperAdmin** | Chief assigns via Supabase or in-app | Invite members, approve pending signups, all features |
| **Member** | Signs up via invite code → needs approval | All social features after approval |
| **Pending** | Just signed up, not approved yet | Only sees waiting screen |

---

## Role Check Logic After Login

```
User logs in
      ↓
Check role from Supabase profiles table
      ↓
role = 'chief'      → go to Home (full access)
role = 'superadmin' → go to Home (with approval panel)
role = 'member'     → go to Home (standard access)
role = 'pending'    → go to Pending Approval Screen
```

---

## Screen Flow — Auth

---

### Screen 1 — Splash Screen

```
┌─────────────────────────┐
│                         │
│                         │
│        [APP LOGO]       │
│        App Name         │
│                         │
│                         │
│   ████████████ (loader) │
└─────────────────────────┘
```

**Logic:** Check if user session exists → if yes skip to role check → if no go to Welcome

---

### Screen 2 — Welcome Screen

```
┌─────────────────────────┐
│                         │
│      [Illustration]     │
│                         │
│   Private. Trusted.     │
│   Just Your Circle.     │
│                         │
│  ┌───────────────────┐  │
│  │  Continue with    │  │
│  │     Gmail  🔵     │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │  Continue with    │  │
│  │  Mobile Number 📱 │  │
│  └───────────────────┘  │
│                         │
│  Already have account?  │
│       [Log In]          │
└─────────────────────────┘
```

**Note:** Both buttons go to Signup if no account, Login if existing.

---

### Screen 3 — Invite Code Screen

*(Shows before signup form — gate check)*

```
┌─────────────────────────┐
│                         │
│   🔐 Enter Invite Code  │
│                         │
│   This app is private.  │
│   You need an invite    │
│   code to join.         │
│                         │
│  ┌───────────────────┐  │
│  │  XXXX-XXXX-XXXX   │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │     Continue      │  │
│  └───────────────────┘  │
│                         │
│  Get code from admin    │
└─────────────────────────┘
```

**Logic:** Validate invite code against Supabase `invites` table → if valid proceed → if invalid show error

---

### Screen 4 — Signup Screen

```
┌─────────────────────────┐
│  ← Back                 │
│                         │
│   Create Your Account   │
│                         │
│  Full Name              │
│  ┌───────────────────┐  │
│  │ Enter full name   │  │
│  └───────────────────┘  │
│                         │
│  [Gmail / Mobile OTP]   │
│  (pre-filled from step) │
│                         │
│  ┌───────────────────┐  │
│  │    Create Account │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

---

### Screen 5 — OTP Verification

*(Only for mobile signup)*

```
┌─────────────────────────┐
│  ← Back                 │
│                         │
│   📱 Verify Number      │
│                         │
│   OTP sent to           │
│   +91 XXXXXXXX89        │
│                         │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│  │ _ │ │ _ │ │ _ │ │ _ ││
│  └───┘ └───┘ └───┘ └───┘│
│                         │
│   Resend OTP (00:45)    │
└─────────────────────────┘
```

---

### Screen 6 — Profile Setup

```
┌─────────────────────────┐
│                         │
│   Setup Your Profile    │
│                         │
│      [📷 Add Photo]     │
│      Tap to upload      │
│                         │
│  Username               │
│  ┌───────────────────┐  │
│  │ @username         │  │
│  └───────────────────┘  │
│                         │
│  Bio (optional)         │
│  ┌───────────────────┐  │
│  │ About you...      │  │
│  └───────────────────┘  │
│                         │
│  ┌───────────────────┐  │
│  │   Finish Setup    │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

**After this → role = 'pending' → go to Pending Screen**

---

### Screen 7 — Pending Approval Screen

```
┌─────────────────────────┐
│                         │
│                         │
│         ⏳              │
│                         │
│   Waiting for Approval  │
│                         │
│   Your account is under │
│   review. The admin     │
│   will approve you      │
│   shortly.              │
│                         │
│   We'll notify you      │
│   once you're approved. │
│                         │
│   [Log Out]             │
│                         │
└─────────────────────────┘
```

**Logic:** Poll or listen via Supabase Realtime → when role changes from `pending` to `member` → auto redirect to Home

---

## Screen Flow — Main App

---

### Screen 8 — Home Feed

```
┌─────────────────────────┐
│ 🔴 LIVE  [App Name]  🔔 │
├─────────────────────────┤
│ Stories/Live Bar:       │
│ [👤+] [👤A] [👤B] [👤C]│
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 👤 Username  • 2h   │ │
│ │                     │ │
│ │   [Photo Post]      │ │
│ │                     │ │
│ │ ❤️ 12  💬 4  📤     │ │
│ │ View all comments   │ │
│ └─────────────────────┘ │
│                         │
│ ┌─────────────────────┐ │
│ │ 👤 Username  • 5h   │ │
│ │   [Photo Post]      │ │
│ │ ❤️ 8   💬 2  📤     │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ 🏠   🔍   ➕   💬   👤 │
└─────────────────────────┘
```

**Top bar:** Live indicator (red dot if someone is live) + notifications
**Stories bar:** Circle avatars — tap to watch live or view stories
**Bottom nav:** Home, Search, Create Post, Messages, Profile

---

### Screen 9 — Create Post

```
┌─────────────────────────┐
│ ✕ Cancel    New Post  ✓ │
├─────────────────────────┤
│                         │
│  ┌─────────────────────┐│
│  │                     ││
│  │   [Selected Photo]  ││
│  │                     ││
│  └─────────────────────┘│
│                         │
│  Write a caption...     │
│  ┌───────────────────┐  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  📷 Change Photo        │
│                         │
└─────────────────────────┘
```

---

### Screen 10 — Messages (DM List)

```
┌─────────────────────────┐
│ Messages           ✏️   │
├─────────────────────────┤
│ Groups                  │
│ ┌─────────────────────┐ │
│ │ 👥 Circle Group     │ │
│ │ Hey everyone! • 2m  │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ Direct Messages         │
│ ┌─────────────────────┐ │
│ │ 👤 Ahmed   • 5m     │ │
│ │ Are you free tonight│ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 👤 Sara    • 1h     │ │
│ │ Seen                │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ 🏠   🔍   ➕   💬   👤 │
└─────────────────────────┘
```

---

### Screen 11 — Chat Screen (DM)

```
┌─────────────────────────┐
│ ← 👤 Ahmed    📞 📹    │
├─────────────────────────┤
│                         │
│         [Today]         │
│                         │
│  ┌──────────────┐       │
│  │ Hey, what's  │       │
│  │ up bro? 😄   │       │
│  └──────────────┘ 10:30 │
│                         │
│       ┌──────────────┐  │
│ 10:31 │ All good!    │  │
│       │ You? 👍      │  │
│       └──────────────┘  │
│                         │
├─────────────────────────┤
│ 📎 │ Type message... │ 🎤│
└─────────────────────────┘
```

**Top right:** Voice call icon + Video call icon

---

### Screen 12 — Voice Call Screen

```
┌─────────────────────────┐
│                         │
│                         │
│         👤              │
│       Ahmed             │
│                         │
│    Calling... / 04:32   │
│                         │
│                         │
│  ┌────┐  ┌────┐ ┌────┐  │
│  │ 🔇 │  │ 🔊 │ │ ⌨️ │  │
│  │Mute│  │Spkr│ │Keyp│  │
│  └────┘  └────┘ └────┘  │
│                         │
│       ┌────────┐        │
│       │  📵    │        │
│       │ End    │        │
│       └────────┘        │
└─────────────────────────┘
```

---

### Screen 13 — Video Call Screen

```
┌─────────────────────────┐
│    [Other user video]   │
│                         │
│                         │
│                         │
│              ┌────────┐ │
│              │[My cam]│ │
│              └────────┘ │
│                         │
│  ┌────┐ ┌────┐ ┌──────┐ │
│  │ 🔇 │ │ 📷 │ │  📵  │ │
│  │Mute│ │Flip│ │ End  │ │
│  └────┘ └────┘ └──────┘ │
└─────────────────────────┘
```

---

### Screen 14 — Go Live Screen

```
┌─────────────────────────┐
│ ✕                  👁 3 │
│                         │
│   [Your Camera Feed]    │
│                         │
│                         │
│  💬 Comments:           │
│  Ahmed: 🔥🔥🔥          │
│  Sara: Heyy!            │
│                         │
│  ┌──────────────────┐   │
│  │   Say something  │   │
│  └──────────────────┘   │
│                         │
│  ┌────┐         ┌─────┐ │
│  │ 🔇 │         │ End │ │
│  │Mute│         │Live │ │
│  └────┘         └─────┘ │
└─────────────────────────┘
```

---

### Screen 15 — Watch Live Screen

```
┌─────────────────────────┐
│ ← Live    👁 3     🔴   │
│                         │
│  [Host Camera Feed]     │
│                         │
│                         │
│  💬 Ahmed: nice 🔥      │
│  💬 Sara: heyyyy!       │
│  💬 You joined          │
│                         │
│  ❤️ (tap to react)      │
│                         │
│  ┌──────────────────┐   │
│  │  Add comment...  │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

---

### Screen 16 — Members Screen

```
┌─────────────────────────┐
│ ← Members          🔍   │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 👤 Imran (Chief) 👑 │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 👤 Ahmed (Admin) ⭐ │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 👤 Sara             │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 👤 Raza             │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ 🏠   🔍   ➕   💬   👤 │
└─────────────────────────┘
```

---

### Screen 17 — Profile Screen

```
┌─────────────────────────┐
│ ←          ⚙️           │
│                         │
│         [Avatar]        │
│        Username         │
│    Bio text here        │
│                         │
│  Posts: 12  Followers: -│
│                         │
│  [📞 Call] [💬 Message] │
├─────────────────────────┤
│ 📷 Posts Grid           │
│ ┌────┐ ┌────┐ ┌────┐    │
│ │img │ │img │ │img │    │
│ ├────┤ ├────┤ ├────┤    │
│ │img │ │img │ │img │    │
│ └────┘ └────┘ └────┘    │
├─────────────────────────┤
│ 🏠   🔍   ➕   💬   👤 │
└─────────────────────────┘
```

---

### Screen 18 — SuperAdmin Panel

*(Only visible to Chief and SuperAdmin)*

```
┌─────────────────────────┐
│ ← Admin Panel           │
├─────────────────────────┤
│ 🔑 Invite Management    │
│ ┌─────────────────────┐ │
│ │ Generate Invite Code│ │
│ │ [Generate + Share]  │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ ⏳ Pending Approvals  3 │
│ ┌─────────────────────┐ │
│ │ 👤 Zaid  [✓] [✗]   │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 👤 Hina  [✓] [✗]   │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ 👥 All Members       8  │
│ [View + Manage roles]   │
└─────────────────────────┘
```

---

## Summary — All Screens

| # | Screen | Who Sees It |
|---|---|---|
| 1 | Splash | Everyone |
| 2 | Welcome | New users |
| 3 | Invite Code | New users |
| 4 | Signup | New users |
| 5 | OTP Verify | Mobile signup |
| 6 | Profile Setup | New users |
| 7 | Pending Approval | Pending users |
| 8 | Home Feed | All approved |
| 9 | Create Post | All approved |
| 10 | Messages List | All approved |
| 11 | Chat / DM | All approved |
| 12 | Voice Call | All approved |
| 13 | Video Call | All approved |
| 14 | Go Live | All approved |
| 15 | Watch Live | All approved |
| 16 | Members | All approved |
| 17 | Profile | All approved |
| 18 | Admin Panel | Chief + SuperAdmin only |

---
