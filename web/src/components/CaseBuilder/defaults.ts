import { CircularPlant, CircularProduct } from "./CircularData";

export interface DefaultProduct extends CircularProduct{
    "initial amounts": Record<string, string>;
    "acquisition cost ($/tonne)": string;
    "disposal cost ($/tonne)": string;
  "disposal limit (tonne)": string;
  "disposal limit (%)": string;
  "transportation cost ($/km/tonne)": string;
  "transportation energy (J/km/tonne)": string;
  "transportation emissions (tonne/km/tonne)": Record<string,string>;
  x: number;
  y: number;
}

export interface DefaultPlant extends CircularPlant{
    locations: Record<string,string>;
  "outputs (tonne/tonne)": Record<string,string>;
  "disposal cost ($/tonne)": Record<string,string>;
  "disposal limit (tonne)": Record<string,string>;
  "emissions (tonne/tonne)": Record<string,string>;
  storage: {
    "cost ($/tonne)": string;
    "limit (tonne)": string;
  };
  "maximum capacity (tonne)": string;
  "minimum capacity (tonne)": string;
  "opening cost (max capacity) ($)": string;
  "opening cost (min capacity) ($)": string;
  "fixed operating cost (max capacity) ($)": string;
  "fixed operating cost (min capacity) ($)": string;
  "variable operating cost ($/tonne)": string;
  "energy (GJ/tonne)": string;
  x: number;
  y: number;
}

export const defaultProduct: DefaultProduct = {
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

export const defaultPlant: DefaultPlant = {
    locations: {},
  "outputs (tonne/tonne)": {},
  "disposal cost ($/tonne)": {},
  "disposal limit (tonne)": {},
  "emissions (tonne/tonne)": {},
  storage: {
    "cost ($/tonne)": "0",
    "limit (tonne)": "0",
  },
  "maximum capacity (tonne)": "0",
  "minimum capacity (tonne)": "0",
  "opening cost (max capacity) ($)": "0",
  "opening cost (min capacity) ($)": "0",
  "fixed operating cost (max capacity) ($)": "0",
  "fixed operating cost (min capacity) ($)": "0",
  "variable operating cost ($/tonne)": "0",
  "energy (GJ/tonne)": "0",
  x: 0,
  y: 0,
};