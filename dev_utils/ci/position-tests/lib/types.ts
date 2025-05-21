export type TestCase = {
  fen: string;
  bms: string[];
  id: string;
  // avoid moves
  ams?: string[];
  comment?: string;
};

export type TestSuite = {
  name: string;
  comment: string;
  tests: TestCase[];
};
