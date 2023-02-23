import {
  exportProduct,
  exportPlant,
  importProduct,
  importList,
  importDict,
  importPlant,
} from "./export";

const sampleProductsOriginal = [
  // basic product
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": "4",
    "disposal cost ($/tonne)": "50",
    "disposal limit (tonne)": "30",
    "disposal limit (%)": "",
    "transportation cost ($/km/tonne)": "0",
    "transportation energy (J/km/tonne)": "10",
    "transportation emissions (tonne/km/tonne)": {
      CO2: "0.5",
    },
    x: null,
    y: null,
  },
  // product with percentage disposal limit
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": "4",
    "disposal cost ($/tonne)": "50",
    "disposal limit (tonne)": "",
    "disposal limit (%)": "10",
    "transportation cost ($/km/tonne)": "5",
    "transportation energy (J/km/tonne)": "10",
    "transportation emissions (tonne/km/tonne)": {
      CO2: "0.5",
    },
    x: null,
    y: null,
  },
  // product using defaults
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": "4",
    "disposal cost ($/tonne)": "50",
    "disposal limit (tonne)": "",
    "disposal limit (%)": "",
    "transportation cost ($/km/tonne)": "5",
    "transportation energy (J/km/tonne)": "",
    "transportation emissions (tonne/km/tonne)": {},
    x: null,
    y: null,
  },
];

const sampleProductsExported = [
  // basic product
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": [4, 8, 16],
    "disposal cost ($/tonne)": [50, 100, 200],
    "disposal limit (tonne)": [30, 30, 30],
    "transportation cost ($/km/tonne)": [0, 0, 0],
    "transportation energy (J/km/tonne)": [10, 10, 10],
    "transportation emissions (tonne/km/tonne)": {
      CO2: [0.5, 0.5, 0.5],
    },
  },
  // product with percentage disposal limit
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": [4, 4, 4],
    "disposal cost ($/tonne)": [50, 50, 50],
    "disposal limit (tonne)": [30, 60, 90],
    "transportation cost ($/km/tonne)": [5, 5, 5],
    "transportation energy (J/km/tonne)": [10, 10, 10],
    "transportation emissions (tonne/km/tonne)": {
      CO2: [0.5, 0.5, 0.5],
    },
  },
  // product using defaults
  {
    "initial amounts": {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "amount (tonne)": [100, 200, 300],
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "amount (tonne)": [100, 200, 300],
      },
      "Park County": {
        "latitude (deg)": 44.4063,
        "longitude (deg)": -109.4153,
        "amount (tonne)": [100, 200, 300],
      },
    },
    "acquisition cost ($/tonne)": [4, 4, 4],
    "disposal cost ($/tonne)": [50, 50, 50],
    "transportation cost ($/km/tonne)": [5, 5, 5],
  },
];

const samplePlantsOriginal = [
  // basic plant
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0,
    },
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "area cost factor": 1.0,
        "initial capacity (tonne)": 0,
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "area cost factor": 0.5,
        "initial capacity (tonne)": 0,
      },
    },
    "disposal cost ($/tonne)": {
      "Hydrogen gas": "0",
      "Carbon dioxide": "0",
      Tar: "200",
    },
    "disposal limit (tonne)": {
      "Hydrogen gas": "10",
      "Carbon dioxide": "",
      Tar: "",
    },
    "emissions (tonne/tonne)": {
      CO2: "100",
    },
    storage: {
      "cost ($/tonne)": "5",
      "limit (tonne)": "10000",
    },
    "maximum capacity (tonne)": "730000",
    "minimum capacity (tonne)": "182500",
    "opening cost (max capacity) ($)": "300000",
    "opening cost (min capacity) ($)": "200000",
    "fixed operating cost (max capacity) ($)": "7000",
    "fixed operating cost (min capacity) ($)": "5000",
    "variable operating cost ($/tonne)": "10",
    x: null,
    y: null,
  },
  // plant with fixed capacity
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0.06,
    },
    "energy (GJ/tonne)": "50",
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "area cost factor": 1.0,
        "initial capacity (tonne)": 0,
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "area cost factor": 0.5,
        "initial capacity (tonne)": 0,
      },
    },
    "disposal cost ($/tonne)": {
      "Hydrogen gas": "0",
      "Carbon dioxide": "0",
      Tar: "200",
    },
    "disposal limit (tonne)": {
      "Hydrogen gas": "10",
      "Carbon dioxide": "",
      Tar: "",
    },
    "emissions (tonne/tonne)": {
      CO2: "100",
    },
    storage: {
      "cost ($/tonne)": "5",
      "limit (tonne)": "10000",
    },
    "maximum capacity (tonne)": "182500",
    "minimum capacity (tonne)": "182500",
    "opening cost (max capacity) ($)": "200000",
    "opening cost (min capacity) ($)": "200000",
    "fixed operating cost (max capacity) ($)": "5000",
    "fixed operating cost (min capacity) ($)": "5000",
    "variable operating cost ($/tonne)": "10",
    x: null,
    y: null,
  },
  // plant with defaults
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0.06,
    },
    "energy (GJ/tonne)": "50",
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "area cost factor": 1.0,
        "initial capacity (tonne)": 0,
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "area cost factor": 0.5,
        "initial capacity (tonne)": 0,
      },
    },
    "disposal cost ($/tonne)": {
      "Hydrogen gas": "",
      "Carbon dioxide": "",
      Tar: "",
    },
    "disposal limit (tonne)": {
      "Hydrogen gas": "",
      "Carbon dioxide": "",
      Tar: "",
    },
    "emissions (tonne/tonne)": {
      CO2: "100",
    },
    storage: {
      "cost ($/tonne)": "5",
      "limit (tonne)": "10000",
    },
    "maximum capacity (tonne)": "730000",
    "minimum capacity (tonne)": "182500",
    "opening cost (max capacity) ($)": "300000",
    "opening cost (min capacity) ($)": "200000",
    "fixed operating cost (max capacity) ($)": "7000",
    "fixed operating cost (min capacity) ($)": "5000",
    "variable operating cost ($/tonne)": "10",
    x: null,
    y: null,
  },
  // plant with expresions
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0,
    },
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        "area cost factor": 1.0,
        "initial capacity (tonne)": 0,
        x: 2,
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        "area cost factor": 0.5,
        "initial capacity (tonne)": 0,
        x: 4,
      },
    },
    "disposal cost ($/tonne)": {
      "Hydrogen gas": "0 + x",
      "Carbon dioxide": "0 + x",
      Tar: "200 + x",
    },
    "disposal limit (tonne)": {
      "Hydrogen gas": "10 + x",
      "Carbon dioxide": "",
      Tar: "",
    },
    "emissions (tonne/tonne)": {
      CO2: "100",
    },
    storage: {
      "cost ($/tonne)": "5 + x",
      "limit (tonne)": "10000 + x",
    },
    "maximum capacity (tonne)": "730000 + x",
    "minimum capacity (tonne)": "182500 + x",
    "opening cost (max capacity) ($)": "300000 + x",
    "opening cost (min capacity) ($)": "200000 + x",
    "fixed operating cost (max capacity) ($)": "7000 + x",
    "fixed operating cost (min capacity) ($)": "5000 + x",
    "variable operating cost ($/tonne)": "10 + x",
    x: null,
    y: null,
  },
];

const samplePlantsExported = [
  //basic plant
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0,
    },
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [0, 0, 0],
            "limit (tonne)": [10, 10, 10],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [0, 0, 0],
          },
          Tar: {
            "cost ($/tonne)": [200, 400, 800],
          },
        },
        storage: {
          "cost ($/tonne)": [5, 10, 20],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [200000, 400000, 800000],
            "fixed operating cost ($)": [5000, 10000, 20000],
            "variable operating cost ($/tonne)": [10, 20, 40],
          },
          730000: {
            "opening cost ($)": [300000, 600000, 1200000],
            "fixed operating cost ($)": [7000, 14000, 28000],
            "variable operating cost ($/tonne)": [10, 20, 40],
          },
        },
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [0, 0, 0],
            "limit (tonne)": [10, 10, 10],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [0, 0, 0],
          },
          Tar: {
            "cost ($/tonne)": [100, 200.0, 400],
          },
        },
        storage: {
          "cost ($/tonne)": [2.5, 5, 10],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [100000, 200000, 400000],
            "fixed operating cost ($)": [2500, 5000, 10000],
            "variable operating cost ($/tonne)": [5, 10, 20],
          },
          730000: {
            "opening cost ($)": [150000, 300000, 600000],
            "fixed operating cost ($)": [3500, 7000, 14000],
            "variable operating cost ($/tonne)": [5, 10, 20],
          },
        },
      },
    },
    "emissions (tonne/tonne)": {
      CO2: [100, 100, 100],
    },
  },
  // plant with fixed capacity
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0.06,
    },
    "energy (GJ/tonne)": [50, 50, 50],
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [0, 0, 0],
            "limit (tonne)": [10, 10, 10],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [0, 0, 0],
          },
          Tar: {
            "cost ($/tonne)": [200.0, 200.0, 200.0],
          },
        },
        storage: {
          "cost ($/tonne)": [5, 5, 5],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [200000, 200000, 200000],
            "fixed operating cost ($)": [5000, 5000, 5000],
            "variable operating cost ($/tonne)": [10, 10, 10],
          },
        },
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [0, 0, 0],
            "limit (tonne)": [10, 10, 10],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [0, 0, 0],
          },
          Tar: {
            "cost ($/tonne)": [100.0, 100.0, 100.0],
          },
        },
        storage: {
          "cost ($/tonne)": [2.5, 2.5, 2.5],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [100000, 100000, 100000],
            "fixed operating cost ($)": [2500, 2500, 2500],
            "variable operating cost ($/tonne)": [5, 5, 5],
          },
        },
      },
    },
    "emissions (tonne/tonne)": {
      CO2: [100, 100, 100],
    },
  },
  // plant with defaults
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0.06,
    },
    "energy (GJ/tonne)": [50, 50, 50],
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        disposal: {},
        storage: {
          "cost ($/tonne)": [5, 5, 5],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [200000, 200000, 200000],
            "fixed operating cost ($)": [5000, 5000, 5000],
            "variable operating cost ($/tonne)": [10, 10, 10],
          },
          730000: {
            "opening cost ($)": [300000, 300000, 300000],
            "fixed operating cost ($)": [7000, 7000, 7000],
            "variable operating cost ($/tonne)": [10, 10, 10],
          },
        },
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        disposal: {},
        storage: {
          "cost ($/tonne)": [2.5, 2.5, 2.5],
          "limit (tonne)": 10000,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182500: {
            "opening cost ($)": [100000, 100000, 100000],
            "fixed operating cost ($)": [2500, 2500, 2500],
            "variable operating cost ($/tonne)": [5, 5, 5],
          },
          730000: {
            "opening cost ($)": [150000, 150000, 150000],
            "fixed operating cost ($)": [3500, 3500, 3500],
            "variable operating cost ($/tonne)": [5, 5, 5],
          },
        },
      },
    },
    "emissions (tonne/tonne)": {
      CO2: [100, 100, 100],
    },
  },
  // plant with expressions
  {
    input: "Baled agricultural biomass",
    "outputs (tonne/tonne)": {
      "Hydrogen gas": 0.095,
      "Carbon dioxide": 1.164,
      Tar: 0,
    },
    locations: {
      "Washakie County": {
        "latitude (deg)": 43.8356,
        "longitude (deg)": -107.6602,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [2, 4, 8],
            "limit (tonne)": [12, 12, 12],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [2, 4, 8],
          },
          Tar: {
            "cost ($/tonne)": [202, 404, 808],
          },
        },
        storage: {
          "cost ($/tonne)": [7, 14, 28],
          "limit (tonne)": 10002,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182502: {
            "opening cost ($)": [200002, 400004, 800008],
            "fixed operating cost ($)": [5002, 10004, 20008],
            "variable operating cost ($/tonne)": [12, 24, 48],
          },
          730002: {
            "opening cost ($)": [300002, 600004, 1200008],
            "fixed operating cost ($)": [7002, 14004, 28008],
            "variable operating cost ($/tonne)": [12, 24, 48],
          },
        },
      },
      "Platte County": {
        "latitude (deg)": 42.1314,
        "longitude (deg)": -104.9676,
        disposal: {
          "Hydrogen gas": {
            "cost ($/tonne)": [2, 4, 8],
            "limit (tonne)": [14, 14, 14],
          },
          "Carbon dioxide": {
            "cost ($/tonne)": [2, 4, 8],
          },
          Tar: {
            "cost ($/tonne)": [102, 204.0, 408],
          },
        },
        storage: {
          "cost ($/tonne)": [4.5, 9, 18],
          "limit (tonne)": 10004,
        },
        "initial capacity (tonne)": 0,
        "capacities (tonne)": {
          182504: {
            "opening cost ($)": [100002, 200004, 400008],
            "fixed operating cost ($)": [2502, 5004, 10008],
            "variable operating cost ($/tonne)": [7, 14, 28],
          },
          730004: {
            "opening cost ($)": [150002, 300004, 600008],
            "fixed operating cost ($)": [3502, 7004, 14008],
            "variable operating cost ($/tonne)": [7, 14, 28],
          },
        },
      },
    },
    "emissions (tonne/tonne)": {
      CO2: [100, 100, 100],
    },
  },
];

const sampleParameters = [
  {
    "time horizon (years)": "3",
    "inflation rate (%)": "100",
  },
  {
    "time horizon (years)": "3",
    "inflation rate (%)": "0",
  },
  {
    "time horizon (years)": "3",
    "inflation rate (%)": "0",
  },
  {
    "time horizon (years)": "3",
    "inflation rate (%)": "100",
  },
];

test("export products", () => {
  for (let i = 0; i < sampleProductsOriginal.length; i++) {
    const original = sampleProductsOriginal[i];
    const exported = sampleProductsExported[i];
    expect(exportProduct(original, sampleParameters[i])).toEqual(exported);

    const [recoveredProd, recoveredParams] = importProduct(exported);
    expect(recoveredProd).toEqual(original);
    expect(recoveredParams).toEqual(sampleParameters[i]);
  }
});

test("export plants", () => {
  for (let i = 0; i < samplePlantsOriginal.length; i++) {
    const original = samplePlantsOriginal[i];
    const exported = samplePlantsExported[i];
    expect(exportPlant(original, sampleParameters[i])).toEqual(exported);

    // const [recoveredPlant, recoveredParams] = importPlant(exported);
    // expect(recoveredPlant).toEqual(original);
    // expect(recoveredParams).toEqual(sampleParameters[i]);
  }
});

test("importList", () => {
  expect(importList("invalid")).toEqual("invalid");
  expect(importList([1, 1, 1])).toEqual("1");
  expect(importList([1, 2, 3])).toEqual("[1,2,3]");
  expect(importList(["A", "A", "A"])).toEqual("A");
});

test("importDict", () => {
  expect(importDict({ a: [5, 5, 5] })).toEqual({ a: "5" });
  expect(importDict({ a: [1, 2, 3] })).toEqual({ a: "[1,2,3]" });
  expect(importDict({ a: "invalid" })).toEqual({ a: "invalid" });
});
