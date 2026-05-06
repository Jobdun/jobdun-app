# GALVANISED — Component Reference
**Australian Tradie Marketplace · v1.0**

All components use tokens from `tokens.rn.ts` (React Native) or `tokens.css` (web).  
Call `useTheme()` at the top of every component file.

---

## TradieCard

The core component. Every tradie list item, search result, and map sheet uses this.

```tsx
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { useTheme, SPACE, RADIUS, FONT, SIZE } from '@/design/tokens.rn';

type TradieCardProps = {
  initials:  string;
  name:      string;
  trade:     string;
  location:  string;
  rating:    number;
  jobCount:  number;
  distanceKm: number;
  available: boolean;
  verified:  boolean;
  onPress:   () => void;
};

export function TradieCard({
  initials, name, trade, location,
  rating, jobCount, distanceKm,
  available, verified, onPress,
}: TradieCardProps) {
  const t = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        {
          backgroundColor: t.card,
          borderColor: t.border,
          opacity: available ? (pressed ? 0.9 : 1) : 0.45,
        },
      ]}
    >
      {/* Top row */}
      <View style={styles.topRow}>
        <View style={[styles.avatar, { backgroundColor: t.foundation }]}>
          <Text style={[styles.avatarText, { color: t.white }]}>{initials}</Text>
        </View>
        <View style={styles.info}>
          <View style={styles.nameRow}>
            <Text style={[styles.name, { color: t.text1 }]}>{name}</Text>
            <View style={styles.ratingRow}>
              <Text style={[styles.ratingN, { color: t.text1 }]}>{rating.toFixed(1)}</Text>
              <Text style={[styles.ratingD, { color: t.text3 }]}>/5</Text>
            </View>
          </View>
          <Text style={[styles.trade, { color: t.text2 }]}>
            {trade} · {location}
          </Text>
          <Text style={[styles.jobCount, { color: t.text3 }]}>
            {jobCount} jobs completed
          </Text>
        </View>
      </View>

      {/* Divider */}
      <View style={[styles.divider, { backgroundColor: t.border }]} />

      {/* Footer row */}
      <View style={styles.footer}>
        {available ? (
          <>
            <View style={[styles.dot, { backgroundColor: t.verified }]} />
            <Text style={[styles.statusText, { color: t.verifiedTx }]}>Available</Text>
            <Text style={[styles.sep, { color: t.border }]}>·</Text>
          </>
        ) : (
          <>
            <View style={[styles.dot, { backgroundColor: t.text3 }]} />
            <Text style={[styles.statusText, { color: t.text3 }]}>Offline</Text>
          </>
        )}

        {verified && available && (
          <Text style={[styles.verified, { color: t.verifiedTx }]}>✓ Verified</Text>
        )}

        {available && (
          <Text style={[styles.distance, { color: t.action }]}>
            {distanceKm.toFixed(1)} km
          </Text>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    borderWidth: 1,
    borderRadius: RADIUS.card,
    padding: SPACE.lg,
    marginBottom: SPACE.sm + 1,
  },
  topRow:     { flexDirection: 'row', alignItems: 'flex-start', gap: SPACE.md },
  avatar: {
    width: SIZE.avatarMd, height: SIZE.avatarMd,
    borderRadius: RADIUS.avatar,
    alignItems: 'center', justifyContent: 'center',
    flexShrink: 0,
  },
  avatarText: {
    fontFamily: FONT.display,
    fontSize: 14,
    fontWeight: '700',
    letterSpacing: 0.04 * 14,
  },
  info:       { flex: 1, minWidth: 0 },
  nameRow:    { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 2 },
  name:       { fontFamily: FONT.semi, fontSize: FONT.size.h3, fontWeight: '600' },
  ratingRow:  { flexDirection: 'row', alignItems: 'baseline', gap: 2 },
  ratingN:    { fontFamily: FONT.display, fontSize: FONT.size.stat, fontWeight: '700', lineHeight: FONT.size.stat },
  ratingD:    { fontFamily: FONT.body, fontSize: FONT.size.caption },
  trade:      { fontFamily: FONT.body, fontSize: FONT.size.label, marginBottom: 2 },
  jobCount:   { fontFamily: FONT.body, fontSize: FONT.size.caption },
  divider:    { height: 1, marginVertical: SPACE.md },
  footer:     { flexDirection: 'row', alignItems: 'center', gap: SPACE.sm },
  dot:        { width: SIZE.dot, height: SIZE.dot, borderRadius: SIZE.dot / 2 },
  statusText: { fontFamily: FONT.semi, fontSize: FONT.size.caption, fontWeight: '600' },
  sep:        { fontFamily: FONT.body, fontSize: FONT.size.caption },
  verified:   { fontFamily: FONT.semi, fontSize: FONT.size.caption, fontWeight: '600' },
  distance:   { fontFamily: FONT.semi, fontSize: FONT.size.caption, fontWeight: '600', marginLeft: 'auto' },
});
```

---

## JobCard

```tsx
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { useTheme, SPACE, RADIUS, FONT } from '@/design/tokens.rn';

type JobCardProps = {
  title:       string;
  description: string;
  rateLabel:   string;
  startLabel:  string;
  distanceKm:  number;
  urgent:      boolean;
  onPress:     () => void;
};

export function JobCard({
  title, description, rateLabel,
  startLabel, distanceKm, urgent, onPress,
}: JobCardProps) {
  const t = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        { backgroundColor: t.card, borderColor: t.border, opacity: pressed ? 0.9 : 1 },
      ]}
    >
      {/* Urgent bar */}
      {urgent && <View style={[styles.urgentBar, { backgroundColor: t.urgent }]} />}

      {/* Urgent badge */}
      {urgent && (
        <View style={[styles.badge, { backgroundColor: t.urgentBg }]}>
          <View style={[styles.badgeDot, { backgroundColor: t.urgent }]} />
          <Text style={[styles.badgeText, { color: t.urgentTx }]}>Urgent</Text>
        </View>
      )}

      {/* Title */}
      <Text style={[styles.title, { color: t.text1 }]} numberOfLines={2}>{title}</Text>

      {/* Description */}
      <Text style={[styles.desc, { color: t.text2 }]} numberOfLines={2}>{description}</Text>

      {/* Meta row */}
      <View style={[styles.meta, { borderTopColor: t.border }]}>
        <View>
          <Text style={[styles.metaLabel, { color: t.text3 }]}>Rate</Text>
          <Text style={[styles.metaValue, { color: t.text1 }]}>{rateLabel}</Text>
        </View>
        <View>
          <Text style={[styles.metaLabel, { color: t.text3 }]}>Start</Text>
          <Text style={[styles.metaValue, { color: t.text1 }]}>{startLabel}</Text>
        </View>
        <View style={{ marginLeft: 'auto', alignItems: 'flex-end' }}>
          <Text style={[styles.metaLabel, { color: t.text3 }]}>Distance</Text>
          <Text style={[styles.metaValue, { color: t.action }]}>{distanceKm.toFixed(1)} km</Text>
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    borderWidth: 1,
    borderRadius: RADIUS.card,
    padding: SPACE.lg,
    marginBottom: SPACE.sm + 1,
    overflow: 'hidden',
  },
  urgentBar: {
    height: 3,
    borderRadius: 0,
    marginTop: -SPACE.lg,
    marginHorizontal: -SPACE.lg,
    marginBottom: SPACE.md,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    alignSelf: 'flex-start',
    paddingHorizontal: 9,
    height: 24,
    borderRadius: RADIUS.sm,
    marginBottom: SPACE.sm,
  },
  badgeDot:   { width: 5, height: 5, borderRadius: 2.5 },
  badgeText:  { fontFamily: FONT.semi, fontSize: 10, fontWeight: '600', letterSpacing: 0.02 * 10 },
  title:      { fontFamily: FONT.display, fontSize: 20, fontWeight: '700', lineHeight: 22, marginBottom: SPACE.xs, letterSpacing: 0.02 * 20 },
  desc:       { fontFamily: FONT.body, fontSize: FONT.size.label, lineHeight: FONT.size.label * 1.5 },
  meta:       { flexDirection: 'row', gap: SPACE.lg, paddingTop: SPACE.md, marginTop: SPACE.md, borderTopWidth: 1 },
  metaLabel:  { fontFamily: FONT.body, fontSize: 10, fontWeight: '500', marginBottom: 2 },
  metaValue:  { fontFamily: FONT.display, fontSize: 15, fontWeight: '700' },
});
```

---

## GvButton

```tsx
import React from 'react';
import { Pressable, Text, StyleSheet, ViewStyle } from 'react-native';
import { useTheme, SPACE, RADIUS, FONT, SIZE } from '@/design/tokens.rn';

type ButtonVariant = 'primary' | 'action' | 'outline' | 'ghost' | 'danger';

type GvButtonProps = {
  label:    string;
  variant?: ButtonVariant;
  onPress:  () => void;
  style?:   ViewStyle;
  disabled?: boolean;
};

export function GvButton({
  label, variant = 'primary', onPress, style, disabled,
}: GvButtonProps) {
  const t = useTheme();

  const variantStyle = {
    primary: { bg: t.btnPri,      text: t.btnPriText, border: 'transparent' },
    action:  { bg: t.action,      text: '#fff',        border: 'transparent' },
    outline: { bg: 'transparent', text: t.text1,       border: t.text1 },
    ghost:   { bg: t.card,        text: t.text2,       border: t.border },
    danger:  { bg: t.urgentBg,    text: t.urgentTx,    border: t.urgent },
  }[variant];

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.btn,
        {
          backgroundColor: variantStyle.bg,
          borderColor: variantStyle.border,
          borderWidth: variant === 'outline' ? 1.5 : variant === 'ghost' || variant === 'danger' ? 1 : 0,
          opacity: disabled ? 0.4 : pressed ? 0.85 : 1,
        },
        style,
      ]}
    >
      <Text style={[styles.label, { color: variantStyle.text }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btn: {
    height: SIZE.btnHeight,
    minHeight: SIZE.touchMin,
    paddingHorizontal: 22,
    borderRadius: RADIUS.btn,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: {
    fontFamily: FONT.semi,
    fontSize: FONT.size.label,
    fontWeight: '600',
    letterSpacing: 0.01 * FONT.size.label,
  },
});
```

---

## GvBadge

```tsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme, SPACE, RADIUS, FONT, SIZE } from '@/design/tokens.rn';

type BadgeVariant = 'verified' | 'available' | 'urgent' | 'pending' | 'pro';

export function GvBadge({ variant }: { variant: BadgeVariant }) {
  const t = useTheme();

  const map = {
    verified:  { bg: t.verifiedBg,  tx: t.verifiedTx,  dot: t.verified,  label: 'Licensed & Verified' },
    available: { bg: t.availableBg, tx: t.availableTx, dot: t.available, label: 'Available Now' },
    urgent:    { bg: t.urgentBg,    tx: t.urgentTx,    dot: t.urgent,    label: 'Urgent' },
    pending:   { bg: t.actionBg,    tx: t.actionTx,    dot: t.action,    label: 'Pending Review' },
    pro:       { bg: t.foundation,  tx: '#fff',         dot: null,        label: 'Tradie Pro' },
  }[variant];

  return (
    <View style={[styles.badge, { backgroundColor: map.bg }]}>
      {map.dot && <View style={[styles.dot, { backgroundColor: map.dot }]} />}
      <Text style={[styles.label, { color: map.tx }]}>{map.label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACE.xs + 1,
    height: SIZE.badgeHeight,
    paddingHorizontal: 11,
    borderRadius: RADIUS.sm,
    alignSelf: 'flex-start',
  },
  dot:   { width: SIZE.dot, height: SIZE.dot, borderRadius: SIZE.dot / 2 },
  label: { fontFamily: FONT.semi, fontSize: FONT.size.badge, fontWeight: '600', letterSpacing: 0.02 * FONT.size.badge },
});
```

---

## SearchBar

```tsx
import React from 'react';
import { View, TextInput, StyleSheet } from 'react-native';
import { SearchIcon } from '@/components/icons'; // your icon set
import { useTheme, SPACE, RADIUS, FONT } from '@/design/tokens.rn';

export function SearchBar({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const t = useTheme();
  return (
    <View style={[styles.wrap, { backgroundColor: t.surf, borderColor: t.border }]}>
      <SearchIcon size={16} color={t.text3} />
      <TextInput
        value={value}
        onChangeText={onChange}
        placeholder="Search trades or skills..."
        placeholderTextColor={t.text2}
        style={[styles.input, { color: t.text1, fontFamily: FONT.body }]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 40,
    borderRadius: RADIUS.input,
    borderWidth: 1,
    paddingHorizontal: 14,
    gap: SPACE.sm,
  },
  input: { flex: 1, fontSize: FONT.size.label, padding: 0 },
});
```

---

## FilterChip

```tsx
import React from 'react';
import { Pressable, Text, StyleSheet } from 'react-native';
import { useTheme, RADIUS, FONT, SIZE } from '@/design/tokens.rn';

export function FilterChip({
  label, active, onPress,
}: { label: string; active: boolean; onPress: () => void }) {
  const t = useTheme();
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.chip,
        active
          ? { backgroundColor: t.foundation }
          : { backgroundColor: t.surf, borderWidth: 1, borderColor: t.border },
      ]}
    >
      <Text style={[styles.label, { color: active ? '#fff' : t.text2 }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    height: SIZE.chipHeight,
    paddingHorizontal: 14,
    borderRadius: RADIUS.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: { fontFamily: FONT.semi, fontSize: FONT.size.caption, fontWeight: '600' },
});
```
