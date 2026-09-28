export function getTimeAgo(date: Date, now = new Date()): string {
  const seconds = Math.max(0, (now.getTime() - date.getTime()) / 1000);
  if (!Number.isFinite(seconds)) return "unknown date";
  if (seconds < 60) return "just now";
  const formatter = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  if (seconds < 3600)
    return formatter.format(-Math.round(seconds / 60), "minute");
  if (seconds < 86400)
    return formatter.format(-Math.round(seconds / 3600), "hour");
  const days = Math.round(seconds / 86400);
  if (days < 6) return formatter.format(-days, "day");
  if (days < 28) return formatter.format(-Math.round(days / 7), "week");
  if (days < 365)
    return formatter.format(-Math.max(1, Math.round(days / 30)), "month");
  return formatter.format(-Math.round(days / 365), "year");
}
