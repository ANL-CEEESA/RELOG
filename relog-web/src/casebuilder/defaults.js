export const defaultProduct = {
  "initial amounts": {},
  "acquisition cost ($/tonne)": "0",
  "disposal cost ($/tonne)": "0",
  "disposal limit (tonne)": "0",
  "disposal limit (%)": "",
  "transportation cost ($/km/tonne)": "0",
  "transportation energy (J/km/tonne)": "0",
  "transportation emissions (tonne/km/tonne)": {},
  x: 0,
  y: 0,
};

export const defaultPlantLocation = {
  "area cost factor": 1.0,
  "latitude (deg)": 0,
  "longitude (deg)": 0,
};

export const defaultPlant = {
  locations: {},
  "outputs (tonne/tonne)": {},
  "disposal cost ($/tonne)": {},
  "disposal limit (tonne)": {},
  "emissions (tonne/tonne)": {},
  storage: {
    "cost ($/tonne)": 0,
    "limit (tonne)": 0,
  },
  "maximum capacity (tonne)": 0,
  "minimum capacity (tonne)": 0,
  "opening cost (max capacity) ($)": 0,
  "opening cost (min capacity) ($)": 0,
  "fixed operating cost (max capacity) ($)": 0,
  "fixed operating cost (min capacity) ($)": 0,
  "variable operating cost ($/tonne)": 0,
  "energy (GJ/tonne)": 0,
  x: 0,
  y: 0,
};

export const defaultData = {
  parameters: {
    "time horizon (years)": "1",
    "building period (years)": "[1]",
    "inflation rate (%)": "0",
    "distance metric": "Euclidean",
  },
  products: {},
  plants: {},
};
