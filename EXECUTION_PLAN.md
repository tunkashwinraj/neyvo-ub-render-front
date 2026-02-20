# Neyvo Pulse - Execution Plan & Architecture

## 🎯 Project Overview

**Problem**: Schools struggle with repetitive calls to students about bills. Students have multiple questions about balances, payment methods, plans, credits, etc.

**Solution**: AI-powered voice system that:
- Automates outbound calls about balances/due dates
- Answers student questions in real-time
- Captures payment barriers/reasons
- Provides flexible customization for schools

---

## 📋 Phase-by-Phase Execution Plan

### **Phase 1: Core Foundation** ✅ (COMPLETED)
- [x] Backend API connected (`https://neyvo-pulse.onrender.com`)
- [x] Firebase integration (client + service account)
- [x] Basic Flutter app structure
- [x] Theme system (SpeariaTheme)
- [x] API client (NeyvoPulseApi)
- [x] Backend connection test page

### **Phase 2: Student Management** 🔄 (IN PROGRESS)
**Goal**: Complete CRUD for students with financial data

**Pages to Build**:
1. ✅ Students List Page (basic - needs enhancement)
2. ✅ Student Detail Page (basic - needs enhancement)
3. ⏳ **Enhanced Student Detail Page**:
   - View full financial history
   - Payment timeline
   - Call history per student
   - Quick actions (call, add payment, schedule reminder)
   - Notes/communication log

**Features**:
- Add/Edit/Delete students
- View balance, due date, late fees
- Payment history
- Call history per student
- Notes/communication log

### **Phase 3: Outbound Calls** 🔄 (IN PROGRESS)
**Goal**: Flexible call initiation with context

**Pages to Build**:
1. ✅ Outbound Calls Page (basic form - needs enhancement)
2. ⏳ **Enhanced Outbound Calls Page**:
   - Select student from list (autocomplete/search)
   - Pre-fill balance/due date from student data
   - Call templates/presets
   - Schedule calls (future calls)
   - Call history with transcripts
3. ⏳ **Call History Page**:
   - List all calls (with filters)
   - View transcripts
   - Play recordings (if available)
   - See student questions asked
   - Payment barriers captured

**Features**:
- Quick call from student list
- Call templates (balance reminder, payment plan inquiry, etc.)
- Schedule future calls
- View call transcripts
- Analyze common questions/barriers

### **Phase 4: Payments & Reminders** ⏳
**Goal**: Track payments and automate reminders

**Pages to Build**:
1. ⏳ **Payments Page**:
   - List all payments (with filters)
   - Add payment (quick action)
   - Payment methods tracking
   - Payment analytics
2. ⏳ **Reminders Page**:
   - List scheduled reminders
   - Create reminder (one-time/recurring)
   - Edit/Delete reminders
   - Reminder templates

**Features**:
- Record payments (manual entry)
- Payment method tracking
- Automatic balance updates
- Schedule reminders (SMS/call)
- Recurring reminder rules

### **Phase 5: Reports & Analytics** ⏳
**Goal**: Insights for schools to improve collections

**Pages to Build**:
1. ⏳ **Reports Dashboard**:
   - Total outstanding balances
   - Payment rate trends
   - Common payment barriers
   - Call success rates
   - Student engagement metrics
2. ⏳ **Analytics Charts**:
   - Balance distribution
   - Payment timeline
   - Question frequency (what students ask most)
   - Barrier analysis (why students can't pay)

**Features**:
- Financial summaries
- Payment trends
- Student engagement metrics
- Barrier analysis
- Export reports (CSV/PDF)

### **Phase 6: Settings & Customization** ⏳
**Goal**: Flexible configuration for schools

**Pages to Build**:
1. ⏳ **Settings Page**:
   - School information
   - VAPI configuration (phone numbers, assistant ID)
   - Call scripts/templates
   - Payment methods
   - Reminder rules
   - AI behavior customization
2. ⏳ **Call Scripts Editor**:
   - Customize AI prompts
   - Add school-specific questions
   - Payment plan options
   - FAQ responses

**Features**:
- School profile
- VAPI phone number management
- Custom call scripts
- Payment method configuration
- Reminder rules
- AI customization (tone, questions, responses)

### **Phase 7: Real-time Updates** ⏳
**Goal**: Live data sync with Firebase

**Implementation**:
- Firestore listeners for students
- Real-time payment updates
- Live call status
- Push notifications for important events

---

## 🏗️ Technical Architecture

### **Frontend (Flutter)**
```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase config
├── api/
│   └── spearia_api.dart        # HTTP client
├── neyvo_pulse_api.dart        # Pulse API wrapper
├── theme/
│   └── spearia_theme.dart      # Design system
├── pulse_route_names.dart      # Route constants
├── pulse_routes.dart           # Route generator
└── screens/
    ├── pulse_shell.dart        # Main layout/nav
    ├── pulse_dashboard_page.dart
    ├── students_list_page.dart
    ├── student_detail_page.dart
    ├── outbound_calls_page.dart
    ├── call_history_page.dart  # NEW
    ├── payments_page.dart      # NEW
    ├── reminders_page.dart
    ├── reports_page.dart
    ├── settings_page.dart
    └── backend_test_page.dart
```

### **Backend (Python/FastAPI)**
- Already deployed at `https://neyvo-pulse.onrender.com`
- Endpoints:
  - `/api/pulse/health`
  - `/api/pulse/students` (CRUD)
  - `/api/pulse/payments` (CRUD)
  - `/api/pulse/calls` (list, create)
  - `/api/pulse/reminders` (CRUD)
  - `/api/pulse/settings` (get, update)
  - `/api/pulse/reports/summary`
  - `/api/pulse/outbound/call` (initiate call)

### **Firebase Integration**
- **Client-side**: Authentication, Firestore reads (if needed)
- **Server-side**: Firestore Admin SDK (via service account)
- **Real-time**: Firestore listeners for live updates

### **VAPI Integration**
- Phone number management
- Assistant configuration
- Call initiation
- Webhook handling (transcripts, status)

---

## 🎨 UI/UX Principles

1. **Clean & Minimal**: Focus on essential actions
2. **Quick Actions**: One-click call from student list
3. **Context-Aware**: Pre-fill data when possible
4. **Real-time Feedback**: Show loading states, success/error messages
5. **Mobile-First**: Responsive design (works on tablets/phones)
6. **Accessibility**: Clear labels, touch targets ≥44px

---

## 🔄 Data Flow

### **Student Financial Data**
```
School Database → Firebase (via API/webhook) → Backend API → Frontend
                                                                    ↓
                                                          Display & Actions
```

### **Outbound Call Flow**
```
Frontend → Backend API → VAPI → Student Phone
                              ↓
                         AI Conversation
                              ↓
                         Transcript → Backend → Firebase → Frontend (live update)
```

### **Payment Flow**
```
Frontend → Backend API → Firebase Update → Real-time sync → Frontend refresh
```

---

## 🚀 Success Factors

### **1. Flexibility**
- ✅ Customizable call scripts
- ✅ Configurable payment methods
- ✅ Flexible reminder rules
- ✅ School-specific FAQs

### **2. Real-time Updates**
- ✅ Firebase listeners for live data
- ✅ Instant payment updates
- ✅ Live call status
- ✅ Push notifications

### **3. User Experience**
- ✅ Quick actions (call from list)
- ✅ Pre-filled forms
- ✅ Search/filter everywhere
- ✅ Clear error messages
- ✅ Loading states

### **4. Analytics**
- ✅ Payment trends
- ✅ Common questions
- ✅ Payment barriers
- ✅ Call success rates

### **5. Integration Ready**
- ✅ API-first design
- ✅ Webhook support
- ✅ Export capabilities
- ✅ Database sync ready

---

## 📝 Next Immediate Steps

1. **Enhance Student Detail Page**:
   - Add payment history section
   - Add call history section
   - Quick actions (call, add payment)
   - Notes/communication log

2. **Improve Outbound Calls Page**:
   - Student selector (autocomplete)
   - Pre-fill from student data
   - Call templates dropdown
   - Schedule future calls option

3. **Create Call History Page**:
   - List all calls with filters
   - View transcripts
   - Search by student/date

4. **Build Payments Page**:
   - List payments
   - Add payment form
   - Payment analytics

5. **Enhance Dashboard**:
   - Stats cards (total balance, students, calls today)
   - Recent activity
   - Quick actions

---

## 🔐 Security & Privacy

- ✅ API authentication (Bearer tokens)
- ✅ Admin tokens for sensitive operations
- ✅ CORS configuration
- ✅ Input validation
- ⏳ Rate limiting (backend)
- ⏳ Audit logs (who did what)

---

## 📊 Demo Data Strategy

1. **Phase 1**: Use hardcoded demo data in backend
2. **Phase 2**: Firebase Firestore with demo collection
3. **Phase 3**: Connect to school database via API/webhook

**Demo Data Structure**:
```json
{
  "students": [
    {
      "id": "student-001",
      "name": "John Doe",
      "phone": "+1234567890",
      "email": "john@example.com",
      "balance": "$1,500.00",
      "due_date": "2026-02-25",
      "late_fee": "$75.00",
      "payment_plan": "monthly",
      "notes": "Student asked about payment plan options"
    }
  ],
  "payments": [...],
  "calls": [...],
  "reminders": [...]
}
```

---

## 🎯 MVP Scope (Minimum Viable Product)

**Must Have**:
- ✅ Student list (view/add/edit)
- ✅ Outbound call initiation
- ✅ Call history with transcripts
- ✅ Payment tracking
- ✅ Basic reports

**Nice to Have**:
- ⏳ Scheduled reminders
- ⏳ Advanced analytics
- ⏳ Custom call scripts
- ⏳ Export reports

**Future**:
- 🔮 Database integration
- 🔮 Multi-school support
- 🔮 SMS reminders
- 🔮 Payment portal integration

---

## 📅 Estimated Timeline

- **Week 1**: Phase 2 (Student Management) ✅
- **Week 2**: Phase 3 (Outbound Calls) 🔄
- **Week 3**: Phase 4 (Payments & Reminders)
- **Week 4**: Phase 5 (Reports & Analytics)
- **Week 5**: Phase 6 (Settings & Customization)
- **Week 6**: Phase 7 (Real-time Updates) + Polish

---

## ✅ Success Metrics

1. **Efficiency**: Reduce manual calls by 80%
2. **Response Time**: Answer student questions in <30 seconds
3. **Payment Rate**: Increase on-time payments by 25%
4. **User Satisfaction**: School staff rate 4.5+/5
5. **Student Engagement**: 70%+ call completion rate

---

## 🛠️ Tools & Technologies

- **Frontend**: Flutter (Web/Mobile)
- **Backend**: Python/FastAPI (Render)
- **Database**: Firebase Firestore
- **Voice**: VAPI
- **Analytics**: Custom dashboards
- **Deployment**: Render (backend), Firebase Hosting (frontend)

---

## 📞 Support & Documentation

- Backend API docs: `/api/docs` (Swagger)
- Frontend code: Well-commented, modular
- User guide: In-app tooltips + help section

---

**Last Updated**: 2026-02-20
**Status**: Phase 2 in progress
