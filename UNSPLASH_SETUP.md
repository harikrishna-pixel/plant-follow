# 🖼️ Unsplash API Setup Guide

## Why Unsplash?
Unsplash provides **high-quality, professional plant images** for your app. It's:
- ✅ **Production-ready** - Used by thousands of apps
- ✅ **Free tier** - 50 requests/hour (enough for most users)
- ✅ **High quality** - Beautiful, curated images
- ✅ **Reliable** - 99.9% uptime

---

## 📝 Step 1: Get Your Free API Key

1. **Go to Unsplash Developers:**
   ```
   https://unsplash.com/developers
   ```

2. **Sign up / Log in** (free account)

3. **Create a new application:**
   - Click "Your apps" → "New Application"
   - Accept the terms
   - App name: `Plant Identifier` (or any name)
   - Description: `Plant identification and care app`

4. **Copy your Access Key** (looks like: `abc123XYZ...`)

---

## 🔧 Step 2: Add API Key to Your App

Open this file:
```
lib/services/search_service.dart
```

Find line **14** and replace the placeholder:

**Before:**
```dart
static const String _accessKey = 'YOUR_UNSPLASH_ACCESS_KEY_HERE';
```

**After:**
```dart
static const String _accessKey = 'your_actual_key_here';
```

---

## ✅ Step 3: Test It!

1. **Hot restart** your app (not hot reload)
2. Go to **Search screen**
3. Pull to refresh
4. Watch the console for:
   ```
   🖼️ Fetching image for: Rose
   ✅ Image found: https://images.unsplash.com/...
   ```

---

## 📊 Usage Limits

**Free Tier:**
- 50 requests per hour
- 5,000 requests per month

**Optimization in our code:**
- ✅ Images are cached (won't re-fetch)
- ✅ 5-second timeout (fast failures)
- ✅ Fallback icons if API fails
- ✅ Only fetches on first load or force refresh

---

## 🚀 Production Ready!

This solution is:
- ✅ **Cached** - Images stored locally after first fetch
- ✅ **Fast** - 5-second timeout per image
- ✅ **Resilient** - Graceful fallback to icons
- ✅ **Scalable** - Works for any plant name
- ✅ **Offline-friendly** - Uses cache when offline

---

## 🔗 Helpful Links

- [Unsplash API Documentation](https://unsplash.com/documentation)
- [Rate Limits](https://unsplash.com/documentation#rate-limiting)
- [Image Guidelines](https://unsplash.com/documentation#guidelines--crediting)

---

## ⚠️ Important Notes

1. **Keep your API key private** - Don't commit to public repos
2. **Monitor usage** - Check your dashboard at https://unsplash.com/oauth/applications
3. **Upgrade if needed** - Paid plans available for higher limits

---

**Questions?** Check the Unsplash docs or reach out!

