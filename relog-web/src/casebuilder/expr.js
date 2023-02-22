import { Jsep } from "jsep";
import { exportValue } from "./export";

export const evaluateExpr = (expr, data) => {
  const node = Jsep.parse(expr);
  return evaluateNode(node, data);
};

const evaluateNode = (node, data) => {
  if (node.type == "BinaryExpression") {
    return evaluateBinaryExprNode(node, data);
  } else if (node.type == "UnaryExpression") {
    return evaluateUnaryExprNode(node, data);
  } else if (node.type == "Literal") {
    return node.value;
  } else if (node.type == "Identifier") {
    return data[node.name];
  } else {
    throw `Unknown type: ${node.type}`;
  }
};

const evaluateBinaryExprNode = (node, data) => {
  const leftVal = evaluateNode(node.left, data);
  const rightVal = evaluateNode(node.right, data);
  if (node.operator == "+") {
    return leftVal + rightVal;
  } else if (node.operator == "*") {
    return leftVal * rightVal;
  } else if (node.operator == "/") {
    return leftVal / rightVal;
  } else if (node.operator == "-") {
    return leftVal - rightVal;
  } else if (node.operator == "^") {
    return Math.pow(leftVal, rightVal);
  } else {
    throw `Unknown operator: ${node.operator}`;
  }
};

const evaluateUnaryExprNode = (node, data) => {
  const arg = evaluateNode(node.argument, data);
  if (node.operator == "+") {
    return arg;
  } else if (node.operator == "-") {
    return -arg;
  } else {
    throw `Unknown operator: ${node.operator}`;
  }
};
