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

export const exportValue = (original, T) => {
  if (isNumeric(original)) {
    if (T) {
      const v = parseFloat(original);
      const result = [];
      for (let i = 0; i < T; i++) result.push(v);
      return result;
    } else {
      return parseFloat(original);
    }
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

export const importList = (args) => {
  if (!args) return "";
  if (Array.isArray(args) && args.length > 0) {
    let isConstant = true;
    for (let i = 1; i < args.length; i++) {
      if (args[i - 1] !== args[i]) {
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

export const exportProduct = (original, T) => {
  const result = {};

  // Copy time series values
  result["initial amounts"] = original["initial amounts"];
  [
    "disposal cost ($/tonne)",
    "disposal limit (tonne)",
    "transportation cost ($/km/tonne)",
    "transportation energy (J/km/tonne)",
  ].forEach((key) => {
    const v = exportValue(original[key], T);
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

export const exportPlant = (original, T) => {
  const result = {};

  // Copy scalar values
  ["input"].forEach((key) => {
    result[key] = original[key];
  });

  // Copy time series values
  ["energy (GJ/tonne)"].forEach((key) => {
    result[key] = exportValue(original[key], T);
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

  const minCap = original["minimum capacity (tonne)"];
  const maxCap = original["maximum capacity (tonne)"];

  result.locations = {};
  for (const [locName, origDict] of Object.entries(original["locations"])) {
    const resDict = (result.locations[locName] = {});
    const capDict = (resDict["capacities (tonne)"] = {});

    const acf = origDict["area cost factor"];

    const exportValueAcf = (obj, T) => {
      const v = exportValue(obj, T);
      if (Array.isArray(v)) {
        return v.map((v) => v * acf);
      }
      return "";
    };

    // Copy scalar values
    ["latitude (deg)", "longitude (deg)"].forEach((key) => {
      resDict[key] = origDict[key];
    });

    // Copy minimum capacity dict
    capDict[minCap] = {};
    for (const [resKeyName, origKeyName] of Object.entries({
      "opening cost ($)": "opening cost (min capacity) ($)",
      "fixed operating cost ($)": "fixed operating cost (min capacity) ($)",
      "variable operating cost ($/tonne)": "variable operating cost ($/tonne)",
    })) {
      capDict[minCap][resKeyName] = exportValueAcf(original[origKeyName], T);
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
        capDict[maxCap][resKeyName] = exportValueAcf(original[origKeyName], T);
      }
    }

    // Copy disposal
    resDict.disposal = {};
    for (const [dispName, dispCost] of Object.entries(
      original["disposal cost ($/tonne)"]
    )) {
      if (dispName.length === 0) continue;
      const v = exportValueAcf(dispCost, T);
      if (v) {
        resDict.disposal[dispName] = { "cost ($/tonne)": v };
        const limit = original["disposal limit (tonne)"][dispName];
        if (isNumeric(limit)) {
          resDict.disposal[dispName]["limit (tonne)"] = exportValue(limit, T);
        }
      }
    }

    // Copy storage
    resDict.storage = {
      "cost ($/tonne)": exportValueAcf(
        original["storage"]["cost ($/tonne)"],
        T
      ),
    };
    const storLimit = original["storage"]["limit (tonne)"];
    if (isNumeric(storLimit)) {
      resDict.storage["limit (tonne)"] = exportValue(storLimit);
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

  // Read time horizon
  let T = result.parameters["time horizon (years)"];
  if (!isNumeric(T)) T = 1;

  // Export products
  for (const [prodName, prodDict] of Object.entries(original.products)) {
    result.products[prodName] = exportProduct(prodDict, T);
  }

  // Export plants
  for (const [plantName, plantDict] of Object.entries(original.plants)) {
    result.plants[plantName] = exportPlant(plantDict, T);
  }
  return result;
};

const compressDisposalLimits = (original, result) => {
  if (!("disposal limit (tonne)" in original)) {
    return;
  }
  const total = computeTotalInitialAmount(original);
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
  const result = {};

  result["initial amounts"] = { ...original["initial amounts"] };

  // Initialize null values
  ["x", "y"].forEach((key) => {
    result[key] = null;
  });

  // Initialize empty values
  ["disposal limit (%)"].forEach((key) => {
    result[key] = "";
  });

  // Import lists
  [
    "transportation energy (J/km/tonne)",
    "transportation cost ($/km/tonne)",
    "disposal cost ($/tonne)",
    "disposal limit (tonne)",
  ].forEach((key) => {
    result[key] = importList(original[key]);
  });

  // Import dicts
  ["transportation emissions (tonne/km/tonne)"].forEach((key) => {
    result[key] = importDict(original[key]);
  });

  // Attempt to convert absolute disposal limits to relative
  compressDisposalLimits(original, result);

  return result;
};

export const importPlant = (original) => {
  const result = {};

  // Initialize null values
  ["x", "y"].forEach((key) => {
    result[key] = null;
  });

  // Import scalar values
  ["input"].forEach((key) => {
    result[key] = original[key];
  });

  // Import timeseries values
  ["energy (GJ/tonne)"].forEach((key) => {
    result[key] = importList(original[key]);
  });

  // Import dicts
  ["outputs (tonne/tonne)", "emissions (tonne/tonne)"].forEach((key) => {
    result[key] = importDict(original[key]);
  });

  // Read locations
  let costsInitialized = false;
  const resLocDict = (result.locations = {});
  for (const [locName, origLocDict] of Object.entries(original["locations"])) {
    resLocDict[locName] = {};

    // Import latitude and longitude
    ["latitude (deg)", "longitude (deg)"].forEach((key) => {
      resLocDict[locName][key] = origLocDict[key];
    });

    const capacities = keysToList(origLocDict["capacities (tonne)"]);
    const last = capacities.length - 1;
    const minCap = capacities[0];
    const maxCap = capacities[last];
    const minCapDict = origLocDict["capacities (tonne)"][minCap];
    const maxCapDict = origLocDict["capacities (tonne)"][maxCap];

    // Import min/max capacity
    if ("minimum capacity (tonne)" in result) {
      if (
        result["minimum capacity (tonne)"] !== minCap ||
        result["maximum capacity (tonne)"] !== maxCap
      ) {
        throw "Data loss";
      }
    } else {
      result["minimum capacity (tonne)"] = minCap;
      result["maximum capacity (tonne)"] = maxCap;
    }

    // Compute area cost factor
    let acf = 1;
    if (costsInitialized) {
      acf = result["opening cost (min capacity) ($)"];
      if (Array.isArray(acf)) acf = acf[0];
      acf = minCapDict["opening cost ($)"][0] / acf;
    }
    resLocDict[locName]["area cost factor"] = acf;

    // Read adjusted costs
    const importListAcf = (obj) => importList(obj.map((v) => v / acf));
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
      check(result["opening cost (max capacity) ($)"], openCostMax);
      check(result["opening cost (min capacity) ($)"], openCostMin);
      check(result["fixed operating cost (max capacity) ($)"], fixCostMax);
      check(result["fixed operating cost (min capacity) ($)"], fixCostMin);
      check(result["variable operating cost ($/tonne)"], varCost);
      check(result["storage"]["cost ($/tonne)"], storCost);
      check(result["storage"]["limit (tonne)"], storLimit);
      check(String(result["disposal cost ($/tonne)"]), String(dispCost));
      check(String(result["disposal limit (tonne)"]), String(dispLimit));
    } else {
      // Initialize plant costs
      costsInitialized = true;
      result["opening cost (max capacity) ($)"] = openCostMax;
      result["opening cost (min capacity) ($)"] = openCostMin;
      result["fixed operating cost (max capacity) ($)"] = fixCostMax;
      result["fixed operating cost (min capacity) ($)"] = fixCostMin;
      result["variable operating cost ($/tonne)"] = varCost;
      result["storage"] = {};
      result["storage"]["cost ($/tonne)"] = storCost;
      result["storage"]["limit (tonne)"] = storLimit;
      result["disposal cost ($/tonne)"] = dispCost;
      result["disposal limit (tonne)"] = dispLimit;
    }
  }

  return result;
};

export const importData = (original) => {
  ["parameters", "plants", "products"].forEach((key) => {
    if (!(key in original)) {
      throw "File not recognized.";
    }
  });

  const result = {};
  result.parameters = importDict(original.parameters);

  // Import products
  result.products = {};
  for (const [prodName, origProdDict] of Object.entries(original.products)) {
    result.products[prodName] = importProduct(origProdDict);
  }

  // Import plants
  result.plants = {};
  for (const [plantName, origPlantDict] of Object.entries(original.plants)) {
    result.plants[plantName] = importPlant(origPlantDict);
  }

  return result;
};
