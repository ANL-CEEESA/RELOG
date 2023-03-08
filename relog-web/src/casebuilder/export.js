import { evaluateExpr } from "./expr";

const isNumeric = (val) => {
  return String(val).length > 0 && !isNaN(val);
};

const keysToList = (obj) => {
  const result = [];
  for (const key of Object.keys(obj)) {
    result.push(key);
  }
  return result;
};

export const exportValue = (original, T, R = 1, data = {}) => {
  try {
    if (T) {
      let v = evaluateExpr(original.toString(), data);
      const result = [];
      for (let i = 0; i < T; i++) {
        result.push(v);
        v *= R;
      }
      return result;
    } else {
      return evaluateExpr(original.toString(), data);
    }
  } catch {
    // ignore;
  }

  try {
    const parsed = JSON.parse(original);
    return parsed;
  } catch {
    // ignore
  }

  return original;
};

const exportValueDict = (original, T) => {
  const result = {};
  for (const [key, val] of Object.entries(original)) {
    if (key.length === 0) continue;
    result[key] = exportValue(val, T);
  }
  if (Object.keys(result).length > 0) {
    return result;
  } else {
    return null;
  }
};

const computeTotalInitialAmount = (prod) => {
  let total = null;
  for (const locDict of Object.values(prod["initial amounts"])) {
    const locAmount = locDict["amount (tonne)"];
    if (!total) total = [...locAmount];
    else {
      for (let i = 0; i < locAmount.length; i++) {
        total[i] += locAmount[i];
      }
    }
  }
  return total;
};

export const importList = (args, R = 1) => {
  if (args === undefined) return "";
  if (Array.isArray(args) && args.length > 0) {
    let isConstant = true;
    for (let i = 1; i < args.length; i++) {
      if (Math.abs(args[i - 1] - args[i] / R) > 1e-3) {
        isConstant = false;
        break;
      }
    }
    if (isConstant) {
      return String(args[0]);
    } else {
      return JSON.stringify(args);
    }
  } else {
    return args;
  }
};

export const importDict = (args) => {
  if (!args) return {};
  const result = {};
  for (const [key, val] of Object.entries(args)) {
    result[key] = importList(val);
  }
  return result;
};

const computeAbsDisposal = (prod) => {
  const disposalPerc = prod["disposal limit (%)"];
  const total = computeTotalInitialAmount(prod);
  const disposalAbs = [];
  for (let i = 0; i < total.length; i++) {
    disposalAbs[i] = (total[i] * disposalPerc) / 100;
  }
  return disposalAbs;
};

const computeInflationAndTimeHorizon = (obj, keys) => {
  for (let i = 0; i < keys.length; i++) {
    const list = obj[keys[i]];
    if (
      Array.isArray(list) &&
      list.length > 1 &&
      isNumeric(list[0]) &&
      isNumeric(list[1]) &&
      Math.abs(list[0]) > 0
    ) {
      return [list[1] / list[0], list.length];
    }
  }
  return [1, 1];
};

export const exportProduct = (original, parameters) => {
  const result = {};

  // Read time horizon
  let T = parameters["time horizon (years)"];
  if (isNumeric(T)) T = parseInt(T);
  else T = 1;

  // Read inflation
  let R = parameters["inflation rate (%)"];
  if (isNumeric(R)) R = parseFloat(R) / 100 + 1;
  else R = 1;

  // Copy constant time series
  result["initial amounts"] = original["initial amounts"];
  ["disposal limit (tonne)", "transportation energy (J/km/tonne)"].forEach(
    (key) => {
      const v = exportValue(original[key], T);
      if (v.length > 0) result[key] = v;
    }
  );

  // Copy cost time series (with inflation)
  [
    "disposal cost ($/tonne)",
    "acquisition cost ($/tonne)",
    "transportation cost ($/km/tonne)",
  ].forEach((key) => {
    const v = exportValue(original[key], T, R);
    if (v.length > 0) result[key] = v;
  });

  // Copy dictionaries
  ["transportation emissions (tonne/km/tonne)"].forEach((key) => {
    const v = exportValueDict(original[key], T);
    if (v) result[key] = v;
  });

  // Transform percentage disposal limits into absolute
  if (isNumeric(original["disposal limit (%)"])) {
    result["disposal limit (tonne)"] = computeAbsDisposal(original);
  }
  return result;
};

export const exportPlant = (original, parameters) => {
  const result = {};

  // Read time horizon
  let T = parameters["time horizon (years)"];
  if (isNumeric(T)) T = parseInt(T);
  else T = 1;

  // Read inflation
  let R = parameters["inflation rate (%)"];
  if (isNumeric(R)) R = parseFloat(R) / 100 + 1;
  else R = 1;

  // Copy scalar values
  ["input"].forEach((key) => {
    result[key] = original[key];
  });

  // Copy time series values
  ["energy (GJ/tonne)"].forEach((key) => {
    result[key] = exportValue(original[key], T);
    if (result[key] === undefined) {
      delete result[key];
    }
  });

  // Copy scalar dicts
  ["outputs (tonne/tonne)"].forEach((key) => {
    const v = exportValueDict(original[key]);
    if (v) result[key] = v;
  });

  // Copy time series dicts
  ["emissions (tonne/tonne)"].forEach((key) => {
    const v = exportValueDict(original[key], T);
    if (v) result[key] = v;
  });

  result.locations = {};
  for (const [locName, origDict] of Object.entries(original["locations"])) {
    const minCap = exportValue(
      original["minimum capacity (tonne)"],
      null,
      null,
      origDict
    );
    const maxCap = exportValue(
      original["maximum capacity (tonne)"],
      null,
      null,
      origDict
    );

    const resDict = (result.locations[locName] = {});
    const capDict = (resDict["capacities (tonne)"] = {});

    const acf = origDict["area cost factor"];

    const exportValueAcf = (obj, data = {}) => {
      const v = exportValue(obj, T, R, data);
      if (Array.isArray(v)) {
        return v.map((v) => v * acf);
      }
      return "";
    };

    // Copy scalar values
    ["latitude (deg)", "longitude (deg)", "initial capacity (tonne)"].forEach(
      (key) => {
        resDict[key] = origDict[key];
      }
    );

    // Copy minimum capacity dict
    capDict[minCap] = {};
    for (const [resKeyName, origKeyName] of Object.entries({
      "opening cost ($)": "opening cost (min capacity) ($)",
      "fixed operating cost ($)": "fixed operating cost (min capacity) ($)",
      "variable operating cost ($/tonne)": "variable operating cost ($/tonne)",
    })) {
      capDict[minCap][resKeyName] = exportValueAcf(
        original[origKeyName],
        origDict
      );
    }

    if (maxCap !== minCap) {
      // Copy maximum capacity dict
      capDict[maxCap] = {};
      for (const [resKeyName, origKeyName] of Object.entries({
        "opening cost ($)": "opening cost (max capacity) ($)",
        "fixed operating cost ($)": "fixed operating cost (max capacity) ($)",
        "variable operating cost ($/tonne)":
          "variable operating cost ($/tonne)",
      })) {
        capDict[maxCap][resKeyName] = exportValueAcf(
          original[origKeyName],
          origDict
        );
      }
    }

    // Copy disposal
    resDict.disposal = {};
    for (const [dispName, dispCost] of Object.entries(
      original["disposal cost ($/tonne)"]
    )) {
      if (dispName.length === 0) continue;
      const v = exportValueAcf(dispCost, origDict);
      if (v) {
        resDict.disposal[dispName] = { "cost ($/tonne)": v };
        const limit = String(original["disposal limit (tonne)"][dispName]);
        if (limit.length > 0) {
          resDict.disposal[dispName]["limit (tonne)"] = exportValue(
            limit,
            T,
            1,
            origDict
          );
        }
      }
    }

    // Copy storage
    resDict.storage = {
      "cost ($/tonne)": exportValueAcf(
        original["storage"]["cost ($/tonne)"],
        origDict
      ),
    };
    const storLimit = original["storage"]["limit (tonne)"];
    if (storLimit.length > 0) {
      resDict.storage["limit (tonne)"] = exportValue(
        storLimit,
        null,
        1,
        origDict
      );
    }
  }

  return result;
};

export const exportData = (original) => {
  const result = {
    parameters: {},
    products: {},
    plants: {},
  };

  // Export parameters
  ["time horizon (years)", "building period (years)"].forEach((key) => {
    result.parameters[key] = exportValue(original.parameters[key]);
  });
  ["distance metric"].forEach((key) => {
    if (original.parameters[key].length > 0) {
      result.parameters[key] = original.parameters[key];
    }
  });

  console.log(original.parameters);
  console.log(result.parameters);

  // Read time horizon
  let T = result.parameters["time horizon (years)"];
  if (!isNumeric(T)) T = 1;

  // Export products
  for (const [prodName, prodDict] of Object.entries(original.products)) {
    result.products[prodName] = exportProduct(prodDict, original.parameters);
  }

  // Export plants
  for (const [plantName, plantDict] of Object.entries(original.plants)) {
    result.plants[plantName] = exportPlant(plantDict, original.parameters);
  }

  // Export original data
  result["case builder"] = original;

  return result;
};

const compressDisposalLimits = (original, result) => {
  if (!("disposal limit (tonne)" in original)) {
    return;
  }
  const total = computeTotalInitialAmount(original);
  if (!total) return;
  const limit = original["disposal limit (tonne)"];
  let perc = Math.round((limit[0] / total[0]) * 1e6) / 1e6;
  for (let i = 1; i < limit.length; i++) {
    if (Math.abs(limit[i] / total[i] - perc) > 1e-5) {
      return;
    }
  }
  result["disposal limit (tonne)"] = "";
  result["disposal limit (%)"] = String(perc * 100);
};

export const importProduct = (original) => {
  const prod = {};
  const parameters = {};

  prod["initial amounts"] = { ...original["initial amounts"] };

  // Initialize null values
  ["x", "y"].forEach((key) => {
    prod[key] = null;
  });

  // Initialize empty values
  ["disposal limit (%)"].forEach((key) => {
    prod[key] = "";
  });

  // Import constant lists
  ["transportation energy (J/km/tonne)", "disposal limit (tonne)"].forEach(
    (key) => {
      prod[key] = importList(original[key]);
    }
  );

  // Compute inflation and time horizon
  const [R, T] = computeInflationAndTimeHorizon(original, [
    "transportation cost ($/km/tonne)",
    "disposal cost ($/tonne)",
    "acquisition cost ($/tonne)",
  ]);
  parameters["inflation rate (%)"] = String((R - 1) * 100);
  parameters["time horizon (years)"] = String(T);

  // Import cost lists
  [
    "transportation cost ($/km/tonne)",
    "disposal cost ($/tonne)",
    "acquisition cost ($/tonne)",
  ].forEach((key) => {
    prod[key] = importList(original[key], R);
  });

  // Import dicts
  ["transportation emissions (tonne/km/tonne)"].forEach((key) => {
    prod[key] = importDict(original[key]);
  });

  // Attempt to convert absolute disposal limits to relative
  compressDisposalLimits(original, prod);

  return [prod, parameters];
};

export const importPlant = (original) => {
  const plant = {};
  const parameters = {};

  plant["storage"] = {};
  plant["storage"]["cost ($/tonne)"] = 0;
  plant["storage"]["limit (tonne)"] = 0;
  plant["disposal cost ($/tonne)"] = 0;
  plant["disposal limit (tonne)"] = 0;

  // Initialize null values
  ["x", "y"].forEach((key) => {
    plant[key] = null;
  });

  // Initialize defaults
  if (!original["outputs (tonne/tonne)"]) {
    original["outputs (tonne/tonne)"] = {};
  }

  // Import scalar values
  ["input"].forEach((key) => {
    plant[key] = original[key];
  });

  // Import timeseries values
  ["energy (GJ/tonne)"].forEach((key) => {
    plant[key] = importList(original[key]);
    if (plant[key] === "") {
      delete plant[key];
    }
  });

  // Import dicts
  ["outputs (tonne/tonne)", "emissions (tonne/tonne)"].forEach((key) => {
    plant[key] = importDict(original[key]);
  });

  let costsInitialized = false;

  // Read locations
  const resLocDict = (plant.locations = {});
  for (const [locName, origLocDict] of Object.entries(original["locations"])) {
    resLocDict[locName] = {};

    // Import scalars
    ["latitude (deg)", "longitude (deg)", "initial capacity (tonne)"].forEach(
      (key) => {
        resLocDict[locName][key] = origLocDict[key];
      }
    );

    const capacities = keysToList(origLocDict["capacities (tonne)"]);
    const last = capacities.length - 1;
    const minCap = capacities[0];
    const maxCap = capacities[last];
    const minCapDict = origLocDict["capacities (tonne)"][minCap];
    const maxCapDict = origLocDict["capacities (tonne)"][maxCap];

    // Import min/max capacity
    if ("minimum capacity (tonne)" in plant) {
      if (
        plant["minimum capacity (tonne)"] !== minCap ||
        plant["maximum capacity (tonne)"] !== maxCap
      ) {
        throw "Data loss";
      }
    } else {
      plant["minimum capacity (tonne)"] = minCap;
      plant["maximum capacity (tonne)"] = maxCap;
    }

    // Compute area cost factor
    let acf = 1;
    if (costsInitialized) {
      acf = plant["opening cost (max capacity) ($)"];
      if (Array.isArray(acf)) acf = acf[0];
      acf = maxCapDict["opening cost ($)"][0] / acf;
    }
    resLocDict[locName]["area cost factor"] = acf;

    const [R, T] = computeInflationAndTimeHorizon(maxCapDict, [
      "opening cost ($)",
      "fixed operating cost ($)",
      "variable operating cost ($/tonne)",
    ]);
    parameters["inflation rate (%)"] = String((R - 1) * 100);
    parameters["time horizon (years)"] = String(T);

    // Initialize defaults
    if (!origLocDict.storage) {
      origLocDict.storage = {
        "cost ($/tonne)": new Array(T).fill(0),
        "limit (tonne)": new Array(T).fill(0),
      };
    }

    // Read adjusted costs
    const importListAcf = (obj) =>
      importList(
        obj.map((v) => v / acf),
        R
      );
    const openCostMax = importListAcf(maxCapDict["opening cost ($)"]);
    const openCostMin = importListAcf(minCapDict["opening cost ($)"]);
    const fixCostMax = importListAcf(maxCapDict["fixed operating cost ($)"]);
    const fixCostMin = importListAcf(minCapDict["fixed operating cost ($)"]);
    const storCost = importListAcf(origLocDict.storage["cost ($/tonne)"]);
    const storLimit = String(origLocDict.storage["limit (tonne)"]);
    const varCost = importListAcf(
      minCapDict["variable operating cost ($/tonne)"]
    );

    const dispCost = {};
    const dispLimit = {};
    for (const prodName of Object.keys(original["outputs (tonne/tonne)"])) {
      dispCost[prodName] = "";
      dispLimit[prodName] = "";

      if (prodName in origLocDict["disposal"]) {
        const prodDict = origLocDict["disposal"][prodName];
        dispCost[prodName] = importListAcf(prodDict["cost ($/tonne)"]);
        if ("limit (tonne)" in prodDict)
          dispLimit[prodName] = importList(prodDict["limit (tonne)"]);
      }
    }

    const check = (left, right) => {
      let valid = true;
      if (isNumeric(left) && isNumeric(right)) {
        valid = Math.abs(left - right) < 1.0;
      } else {
        valid = left === right;
      }
      if (!valid)
        console.warn(`Data loss detected: ${locName}, ${left} != ${right}`);
    };

    if (costsInitialized) {
      // Verify that location costs match the previously initialized ones
      check(plant["opening cost (max capacity) ($)"], openCostMax);
      check(plant["opening cost (min capacity) ($)"], openCostMin);
      check(plant["fixed operating cost (max capacity) ($)"], fixCostMax);
      check(plant["fixed operating cost (min capacity) ($)"], fixCostMin);
      check(plant["variable operating cost ($/tonne)"], varCost);
      check(plant["storage"]["cost ($/tonne)"], storCost);
      check(plant["storage"]["limit (tonne)"], storLimit);
      check(String(plant["disposal cost ($/tonne)"]), String(dispCost));
      check(String(plant["disposal limit (tonne)"]), String(dispLimit));
    } else {
      // Initialize plant costs
      costsInitialized = true;
      plant["opening cost (max capacity) ($)"] = openCostMax;
      plant["opening cost (min capacity) ($)"] = openCostMin;
      plant["fixed operating cost (max capacity) ($)"] = fixCostMax;
      plant["fixed operating cost (min capacity) ($)"] = fixCostMin;
      plant["variable operating cost ($/tonne)"] = varCost;
      plant["storage"] = {};
      plant["storage"]["cost ($/tonne)"] = storCost;
      plant["storage"]["limit (tonne)"] = storLimit;
      plant["disposal cost ($/tonne)"] = dispCost;
      plant["disposal limit (tonne)"] = dispLimit;
      parameters["inflation rate (%)"] = String((R - 1) * 100);
    }
  }

  return [plant, parameters];
};

export const importData = (original) => {
  ["parameters", "plants", "products"].forEach((key) => {
    if (!(key in original)) {
      throw "File not recognized.";
    }
  });

  const result = {};
  result.parameters = importDict(original.parameters);
  ["building period (years)"].forEach((k) => {
    result.parameters[k] = JSON.stringify(original.parameters[k]);
  });
  ["distance metric"].forEach((k) => {
    result.parameters[k] = original.parameters[k];
  });
  result.parameters["inflation rate (%)"] = "0";

  // Import products
  result.products = {};
  for (const [prodName, origProdDict] of Object.entries(original.products)) {
    const [recoveredProd, recoveredParams] = importProduct(origProdDict);
    result.products[prodName] = recoveredProd;
    result.parameters = { ...result.parameters, ...recoveredParams };
  }

  // Import plants
  result.plants = {};
  for (const [plantName, origPlantDict] of Object.entries(original.plants)) {
    const [recoveredPlant, recoveredParams] = importPlant(origPlantDict);
    result.plants[plantName] = recoveredPlant;
    result.parameters = { ...result.parameters, ...recoveredParams };
  }

  return result;
};
