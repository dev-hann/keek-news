const MINUTE = 60;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** How long ago `dateTime` was, in Korean and in round units: 방금 전, 3분 전, 2시간 전… */
export function formatTimeAgo(dateTime: Date, now: Date = new Date()): string {
  const seconds = Math.floor((now.getTime() - dateTime.getTime()) / 1000);
  if (seconds < MINUTE) return '방금 전';
  if (seconds < HOUR) return `${Math.floor(seconds / MINUTE)}분 전`;
  if (seconds < DAY) return `${Math.floor(seconds / HOUR)}시간 전`;
  const days = Math.floor(seconds / DAY);
  if (days < 7) return `${days}일 전`;
  if (days < 30) return `${Math.floor(days / 7)}주 전`;
  if (days < 365) return `${Math.floor(days / 30)}개월 전`;
  return `${Math.floor(days / 365)}년 전`;
}
