# Project Folder Structure & Technical System Flow

---

## ⚖️ Legal Question First — Is TCP 443 Bypass Illegal?

**Honest answer: Gray area, but you are not doing anything criminal.**

Here is the reality broken down:

| Country | VoIP Law | Your Case |
|---|---|---|
| UAE | TRA restricts licensed VoIP providers (Skype, WhatsApp calls) | Your private app is not a VoIP provider. It's a personal communication tool using HTTPS port. |
| Saudi Arabia | CITC restricts consumer VoIP services | Same as UAE — private apps are not targeted |
| India | No VoIP restrictions | Fully legal |

**What TCP 443 actually is:** It is just the standard HTTPS port that every website uses. You are not hacking anything. LiveKit sends media packets that look like normal web traffic. You are not breaking encryption, not intercepting anyone, not running a commercial VoIP service.

**What is actually illegal:** Running a commercial VoIP service without a telecom license in UAE (like building a competitor to Etisalat).

**What you are doing:** Building a private app for friends and family. No different from a company building an internal communication tool. Zoom, Microsoft Teams, Google Meet all work in UAE using the same TCP 443 approach.

**Bottom line:** You are fine. Just do not market it as a VoIP service or sell it commercially in UAE.

---

## 📁 Flutter Project Folder Structure

Clean Architecture — Feature First — Scalable

```
lib/
│
├── main.dart
├── app.dart                          # App entry, theme, router init
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # App name, version, etc
│   │   ├── supabase_constants.dart   # Table names, bucket names
│   │   └── livekit_constants.dart    # LiveKit server URL, config
│   │
│   ├── errors/
│   │   ├── failures.dart             # Auth, network, server failures
│   │   └── exceptions.dart
│   │
│   ├── network/
│   │   ├── supabase_client.dart      # Supabase init + singleton
│   │   └── imagekit_service.dart     # ImageKit upload helper
│   │
│   ├── router/
│   │   ├── app_router.dart           # GoRouter config
│   │   ├── app_routes.dart           # Route name constants
│   │   └── router_guards.dart        # Role-based route protection
│   │
│   ├── theme/
│   │   ├── app_theme.dart            # Light/dark theme
│   │   ├── app_colors.dart           # Color palette
│   │   └── app_typography.dart       # Font styles
│   │
│   └── utils/
│       ├── date_utils.dart
│       ├── invite_utils.dart         # Generate/validate invite codes
│       └── permission_utils.dart     # Camera, mic permissions
│
├── features/
│   │
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── auth_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── sign_in_with_gmail.dart
│   │   │       ├── sign_in_with_otp.dart
│   │   │       ├── verify_otp.dart
│   │   │       ├── validate_invite_code.dart
│   │   │       └── sign_out.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart
│   │       └── screens/
│   │           ├── splash_screen.dart
│   │           ├── welcome_screen.dart
│   │           ├── invite_code_screen.dart
│   │           ├── signup_screen.dart
│   │           ├── otp_screen.dart
│   │           ├── profile_setup_screen.dart
│   │           └── pending_approval_screen.dart
│   │
│   ├── feed/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── feed_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── post_model.dart
│   │   │   │   └── comment_model.dart
│   │   │   └── repositories/
│   │   │       └── feed_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── post_entity.dart
│   │   │   │   └── comment_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── feed_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_feed.dart
│   │   │       ├── create_post.dart
│   │   │       ├── delete_post.dart
│   │   │       ├── like_post.dart
│   │   │       └── add_comment.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── feed_provider.dart
│   │       └── screens/
│   │           ├── home_feed_screen.dart
│   │           ├── create_post_screen.dart
│   │           └── post_detail_screen.dart
│   │
│   ├── messaging/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── messaging_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── message_model.dart
│   │   │   │   └── group_model.dart
│   │   │   └── repositories/
│   │   │       └── messaging_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── message_entity.dart
│   │   │   │   └── group_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── messaging_repository.dart
│   │   │   └── usecases/
│   │   │       ├── send_message.dart
│   │   │       ├── get_messages.dart
│   │   │       ├── create_group.dart
│   │   │       └── get_groups.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── messaging_provider.dart
│   │       └── screens/
│   │           ├── messages_list_screen.dart
│   │           ├── chat_screen.dart
│   │           └── group_chat_screen.dart
│   │
│   ├── calls/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── calls_remote_datasource.dart  # LiveKit token gen
│   │   │   ├── models/
│   │   │   │   └── call_model.dart
│   │   │   └── repositories/
│   │   │       └── calls_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── call_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── calls_repository.dart
│   │   │   └── usecases/
│   │   │       ├── start_voice_call.dart
│   │   │       ├── start_video_call.dart
│   │   │       └── start_group_call.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── calls_provider.dart
│   │       └── screens/
│   │           ├── voice_call_screen.dart
│   │           ├── video_call_screen.dart
│   │           └── group_call_screen.dart
│   │
│   ├── live/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── live_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── live_session_model.dart
│   │   │   └── repositories/
│   │   │       └── live_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── live_session_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── live_repository.dart
│   │   │   └── usecases/
│   │   │       ├── start_live.dart
│   │   │       ├── end_live.dart
│   │   │       └── join_live.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── live_provider.dart
│   │       └── screens/
│   │           ├── go_live_screen.dart
│   │           └── watch_live_screen.dart
│   │
│   ├── profile/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           ├── profile_screen.dart
│   │           └── edit_profile_screen.dart
│   │
│   ├── members/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── members_screen.dart
│   │
│   └── admin/
│       ├── data/
│       ├── domain/
│       │   └── usecases/
│       │       ├── approve_member.dart
│       │       ├── reject_member.dart
│       │       ├── generate_invite_code.dart
│       │       └── assign_role.dart
│       └── presentation/
│           ├── providers/
│           │   └── admin_provider.dart
│           └── screens/
│               └── admin_panel_screen.dart
│
└── shared/
    ├── widgets/
    │   ├── app_button.dart
    │   ├── app_text_field.dart
    │   ├── app_avatar.dart
    │   ├── post_card.dart
    │   ├── story_bubble.dart
    │   ├── message_bubble.dart
    │   └── loading_overlay.dart
    └── extensions/
        ├── context_extensions.dart
        └── string_extensions.dart
```

---

## ⚙️ Technical System Flow

---

### 1. App Launch Flow

```
App starts
    │
    ▼
Supabase.initialize()
LiveKit config loaded
    │
    ▼
Check session token
    │
    ├── No session ──────► Welcome Screen
    │
    └── Session exists
            │
            ▼
        Fetch user role from profiles table
            │
            ├── chief / superadmin / member ──► Home Feed
            │
            └── pending ──────────────────────► Pending Screen
```

---

### 2. Auth + Invite Flow

```
New user gets invite link from friend/admin
        │
        ▼
Opens APK → Invite Code Screen
        │
        ▼
Code validated against Supabase invites table
        │
        ├── Invalid ──► Show error
        │
        └── Valid
                │
                ▼
            Signup (Gmail OAuth or Mobile OTP)
                │
                ▼
            Profile setup
                │
                ▼
            Insert into profiles table
            role = 'pending'
            invite_code marked as used
                │
                ▼
            Pending Approval Screen
            (Supabase Realtime listening for role change)
                │
                ▼
            SuperAdmin approves in Admin Panel
            role updated to 'member' in Supabase
                │
                ▼
            Realtime triggers → app auto-redirects to Home
```

---

### 3. Photo Post Flow

```
User taps + (Create Post)
        │
        ▼
Pick photo from gallery
        │
        ▼
Upload photo to ImageKit
        │
        ▼
ImageKit returns CDN URL
        │
        ▼
Insert into Supabase posts table
{ user_id, image_url, caption, created_at }
        │
        ▼
Supabase Realtime broadcasts new post
        │
        ▼
All online users see post appear in feed instantly
```

---

### 4. Messaging Flow

```
User A opens chat with User B
        │
        ▼
Subscribe to Supabase Realtime channel
channel: dm_{userA_id}_{userB_id}
        │
        ▼
User A types and sends message
        │
        ▼
Message inserted into messages table
        │
        ▼
Supabase Realtime pushes to User B instantly
        │
        ▼
User B sees message without refresh
```

---

### 5. Voice / Video Call Flow

```
User A taps call button on User B's profile
        │
        ▼
Supabase Edge Function generates LiveKit token
{ room: call_{A}_{B}, identity: userA, permissions: publish+subscribe }
        │
        ▼
Signal sent to User B via Supabase Realtime
{ type: 'incoming_call', room_id, caller_info }
        │
        ▼
User B sees incoming call screen
        │
        ├── Declines ──► Realtime signal back → call ended screen
        │
        └── Accepts
                │
                ▼
            Both users connect to LiveKit server
            using their tokens
                │
                ▼
            LiveKit establishes WebRTC connection
            Tries UDP first → falls back to TCP 443
            (Gulf countries use TCP 443 automatically)
                │
                ▼
            Real-time voice/video streams
            Nothing stored anywhere
                │
                ▼
            Either user ends call
            LiveKit room closes
            All data vanishes — zero storage
```

---

### 6. Live Streaming Flow

```
Host taps Go Live
        │
        ▼
Supabase Edge Function creates live_sessions record
{ host_id, status: 'live', started_at }
        │
        ▼
Realtime notification pushed to all circle members
"[Username] is now live!"
        │
        ▼
Host gets LiveKit publisher token
Starts streaming from camera
        │
        ▼
Viewers tap notification → join live screen
Each viewer gets LiveKit subscriber token
        │
        ▼
Viewers receive HD stream from host via LiveKit
Viewer comments go through Supabase Realtime
        │
        ▼
Host ends live
live_sessions record updated → status: 'ended'
LiveKit room closes
Stream data gone — nothing saved
```

---

### 7. Role-Based Route Guard

```dart
// router_guards.dart logic

String? roleGuard(UserRole role, String targetRoute) {
  if (role == UserRole.pending) {
    return AppRoutes.pendingApproval;   // block everything
  }
  if (targetRoute == AppRoutes.adminPanel) {
    if (role != UserRole.chief && role != UserRole.superAdmin) {
      return AppRoutes.home;            // block non-admins
    }
  }
  return null;                          // allow
}
```

---

### 8. Scalability Plan

| Current Scale | Future Scale | What to Change |
|---|---|---|
| ~30 friends | ~500 users | Upgrade Supabase plan, upgrade VPS to CX32 |
| 1 LiveKit VPS | 1000+ concurrent calls | Add 2nd LiveKit node, add load balancer |
| ImageKit free | Heavy image traffic | Upgrade ImageKit plan (~$49/mo) |
| Single admin | Multiple circles | Add `circle_id` to all tables, multi-tenant |
| Manual APK share | Large distribution | Firebase App Distribution |

**The schema is already built for scale** — adding `circle_id` to tables later makes this fully multi-tenant without rewriting business logic.

---
