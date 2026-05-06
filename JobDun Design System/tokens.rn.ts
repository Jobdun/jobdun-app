/**
 * GALVANISED — React Native Tokens
 * Australian Tradie Marketplace · v1.0
 *
 * Usage:
 *   import { useTheme } from '@/design/tokens.rn';
 *   const t = useTheme();
 *   style={{ backgroundColor: t.card }}
 */

import { useColorScheme } from 'react-native';

/* ─── Primitives (fixed — never change between modes) ─── */
const PRIMITIVES = {
  foundation:   '#252D34',
  action:       '#CC4A10',
  actionBg:     '#FAE4D8',
  actionTx:     '#7A2808',
  verified:     '#0D8A5A',
  verifiedBg:   '#E6F7F1',
  verifiedTx:   '#0D6644',
  urgent:       '#C73B2E',   // FIXED — never changes
  urgentBg:     '#FDECEA',   // FIXED — never changes
  urgentTx:     '#A32E24',   // FIXED — never changes
  available:    '#1A7AD4',   // FIXED — never changes
  availableBg:  '#E6F3FF',   // FIXED — never changes
  availableTx:  '#1254A0',   // FIXED — never changes
  white:        '#FFFFFF',
};

/* ─── Light semantic tokens ─── */
const LIGHT = {
  ...PRIMITIVES,
  bg:         '#F4F6F8',
  surf:       '#EAEEF2',
  card:       '#FFFFFF',
  border:     '#D4D9DF',
  text1:      '#252D34',
  text2:      '#5A6872',
  text3:      '#A0ACB8',
  btnPri:     '#252D34',
  btnPriText: '#FFFFFF',
};

/* ─── Dark semantic tokens ─── */
const DARK = {
  ...PRIMITIVES,
  bg:         '#0E1216',
  surf:       '#1C2428',
  card:       '#252D34',
  border:     '#303A44',
  text1:      '#E8ECF2',
  text2:      '#7A8898',
  text3:      '#505C68',
  // Primary button FLIPS — foundation is invisible on dark bg
  btnPri:     '#CC4A10',
  btnPriText: '#FFFFFF',
};

/* ─── Spacing (4pt grid) ─── */
export const SPACE = {
  xs:   4,
  sm:   8,
  md:   12,
  lg:   16,
  xl:   20,    // screen horizontal padding — always
  '2xl': 32,
  '3xl': 48,   // minimum touch target
  '4xl': 64,
} as const;

/* ─── Border radius ─── */
export const RADIUS = {
  sm:     5,   // badges
  md:     8,   // chips
  btn:    9,   // buttons
  card:   14,  // cards — never exceed
  input:  10,  // search, inputs
  avatar: 10,  // avatar blocks
} as const;

/* ─── Typography ─── */
export const FONT = {
  display: 'BarlowCondensed-Bold',
  heading: 'BarlowCondensed-Bold',
  semi:    'Barlow-SemiBold',
  body:    'Barlow-Regular',
  medium:  'Barlow-Medium',

  size: {
    display: 40,
    h1:      28,
    h2:      20,
    h3:      16,
    body:    15,
    label:   13,
    caption: 11,
    stat:    20,
    badge:   11,
  },

  lineHeight: {
    tight:   1.0,
    snug:    1.4,
    normal:  1.7,
  },
} as const;

/* ─── Sizing ─── */
export const SIZE = {
  touchMin:    48,
  btnHeight:   48,
  chipHeight:  30,
  badgeHeight: 28,
  avatarMd:    44,
  avatarLg:    50,
  navHeight:   62,
  dot:         6,
} as const;

/* ─── Animation ─── */
export const ANIM = {
  fast:   100,
  normal: 150,  // hard ceiling
} as const;

/* ─── Hook ─── */
export type Theme = typeof LIGHT;

export function useTheme(): Theme {
  const scheme = useColorScheme();
  return scheme === 'dark' ? DARK : LIGHT;
}

export { LIGHT as lightTokens, DARK as darkTokens, PRIMITIVES };
export default { SPACE, RADIUS, FONT, SIZE, ANIM, useTheme };
