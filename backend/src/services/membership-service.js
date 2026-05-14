export const membershipPlans = [
  {
    tier: 'free',
    title: 'Free',
    priceLabel: '免费',
    features: [
      '作品基础点评',
      '成长档案记录',
      '历史作品查看',
    ],
    generationEnabled: false,
  },
  {
    tier: 'pro',
    title: 'Pro',
    priceLabel: '待定',
    features: [
      '作品基础点评',
      '成长档案记录',
      '优化方向参考图',
      '更完整的个性化建议',
    ],
    generationEnabled: true,
  },
];

export function getMembershipPlan(tier) {
  return membershipPlans.find((plan) => plan.tier === tier) ?? membershipPlans[0];
}

export function canGenerateReference(tier) {
  return getMembershipPlan(tier).generationEnabled;
}
