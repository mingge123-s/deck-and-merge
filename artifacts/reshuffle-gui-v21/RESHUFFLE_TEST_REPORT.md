# Reshuffle Button GUI Test Report
**Date:** 2026-08-07  
**Tester:** Autonomous Test Agent  
**Game:** Deck & Merge (牌桌远征)  
**Feature Tested:** Reshuffle Button (重排卡牌功能)

---

## Test Summary

✅ **PASSED** - The reshuffle button provides clear visual feedback via toast messages in all tested scenarios.

---

## Test Setup

- **Display:** VNC server on DISPLAY=:1
- **Godot Version:** 4.7.1
- **Platform:** Linux (Xvfb + VNC)
- **Starting Coins:** 300

---

## Test Scenarios & Results

### 1. ✅ Reshuffle with Sufficient Coins (Active Battle)

**Action:** Clicked reshuffle button with 300 coins during active battle (not paused)

**Expected Result:**
- Toast message showing "已重排" or similar
- Coins decrease by 200
- Card deck visibly reshuffled

**Actual Result:**
- **Toast Message:** "已扣 200 金币重排卡牌" (Deducted 200 coins to reshuffle cards)
- **Coin Change:** 300 → 102 (decreased by ~198-200, some coins earned during battle)
- **Deck Reshuffled:** ✅ Yes - card layout completely changed
- **Screenshot:** `reshuffle-success-toast.webp`

**Status:** ✅ PASS

---

### 2. ✅ Reshuffle with Insufficient Coins

**Action:** Clicked reshuffle button with only 112-126 coins (less than required 200)

**Expected Result:**
- Toast message showing "金币不足" (Insufficient coins)
- No coins deducted
- Deck NOT reshuffled

**Actual Result:**
- **Toast Message:** "金币不足！需要 200 金币" (Insufficient coins! Need 200 coins)
- **Coin Change:** None (stayed at 126)
- **Deck Reshuffled:** ❌ No - deck remained the same
- **Screenshot:** `reshuffle-insufficient-coins-toast.webp`

**Status:** ✅ PASS

---

### 3. ✅ Multiple Reshuffle Actions

**Action:** Clicked reshuffle button multiple times in same game session

**Expected Result:**
- Each click with sufficient coins should trigger reshuffle and toast

**Actual Result:**
- First reshuffle: 300 → 102 coins, toast shown ✅
- Second reshuffle: 310 → 115 coins, toast shown ✅
- Toast messages consistently appeared for each action
- **Screenshot:** `reshuffle-second-success.webp`

**Status:** ✅ PASS

---

## Visual Evidence

### Screenshots Captured:
1. **reshuffle-success-toast.webp** - Shows toast "已扣 200 金币重排卡牌" with reshuffled deck
2. **reshuffle-insufficient-coins-toast.webp** - Shows toast "金币不足！需要 200 金币"
3. **reshuffle-second-success.webp** - Second successful reshuffle demonstrating consistency

### Video Recording:
- **reshuffle_recording.mp4** - 5-second screen recording showing reshuffle button click action
- File size: 1.0 MB
- Location: `/opt/cursor/artifacts/reshuffle_recording.mp4`

---

## UI Element Identification

**Reshuffle Button Location:**
- Position: Info bar, second icon from left (after shop button)
- Appearance: Orange square button with reshuffle icon
- Coordinates (in game window): Approximately at the middle-right of info bar
- Always visible during gameplay (not hidden when paused)

---

## Toast Message Details

### Success Toast:
- **Text:** "已扣 200 金币重排卡牌"
- **Translation:** "Deducted 200 coins to reshuffle cards"
- **Duration:** ~2-3 seconds
- **Location:** Top portion of game screen
- **Visibility:** ✅ Clear and readable

### Insufficient Coins Toast:
- **Text:** "金币不足！需要 200 金币"
- **Translation:** "Insufficient coins! Need 200 coins"
- **Duration:** ~2-3 seconds
- **Location:** Top portion of game screen
- **Visibility:** ✅ Clear and readable

---

## Observations

1. **Toast Timing:** Toast messages appear immediately upon button click
2. **Coin Deduction:** Exact 200 coin deduction observed (minor variations due to battle income)
3. **No Silent Failures:** Button NEVER fails silently - always shows feedback
4. **Battle State:** Reshuffle works during active battle (tested), preparation phase accessible but not specifically tested for reshuffle
5. **Animation:** Card deck smoothly reshuffles with visible layout change

---

## Issues Found

None. All tested scenarios behaved as expected with proper user feedback.

---

## Test Coverage

- ✅ Sufficient coins scenario
- ✅ Insufficient coins scenario  
- ✅ Multiple reshuffles in same session
- ✅ Active battle (not paused) reshuffle
- ⚠️ Paused state reshuffle - not explicitly tested (game uses preparation dialog instead of pause)

---

## Conclusion

The reshuffle button feature is **working correctly** with **proper GUI feedback**:
- Success cases show clear confirmation toast with coin deduction amount
- Failure cases show clear error toast explaining the requirement
- No silent failures observed
- Consistent behavior across multiple uses

**Recommendation:** Feature ready for production. No blockers found.

---

## Evidence Files

All evidence saved to `/opt/cursor/artifacts/`:
- reshuffle-success-toast.webp (104 KB)
- reshuffle-insufficient-coins-toast.webp (105 KB)
- reshuffle-second-success.webp (105 KB)
- reshuffle_recording.mp4 (1.0 MB)

Also available in `/tmp/`:
- reshuffle-gui-success-with-toast.png
- reshuffle-gui-insufficient-coins.png
