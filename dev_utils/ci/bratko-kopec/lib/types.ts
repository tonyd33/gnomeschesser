export type TestCase = {
  fen: string;
  bms: string[];
  id: string;
  // avoid moves
  ams?: string[];
  comment?: string;
};

