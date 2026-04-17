const pad2 = (value: number): string => {
  return value.toString().padStart(2, "0");
};

export const toDateKeyUtc = (date: Date): string => {
  const year = date.getUTCFullYear();
  const month = pad2(date.getUTCMonth() + 1);
  const day = pad2(date.getUTCDate());

  return `${year}-${month}-${day}`;
};
