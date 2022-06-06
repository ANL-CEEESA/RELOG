import React, { useEffect } from "react";
import ReactFlow, { Background, isNode, Controls } from "react-flow-renderer";
import Section from "../common/Section";
import Card from "../common/Card";
import Button from "../common/Button";
import styles from "./PipelineBlock.module.css";
import dagre from "dagre";

window.nextX = 15;
window.nextY = 15;

export const randomPosition = () => {
  window.nextY += 60;
  if (window.nextY >= 500) {
    window.nextY = 15;
    window.nextX += 150;
  }
  return [window.nextX, window.nextY];
};

const getLayoutedElements = (elements) => {
  const nodeWidth = 125;
  const nodeHeight = 45;
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({ rankdir: "LR" });
  elements.forEach((el) => {
    if (isNode(el)) {
      dagreGraph.setNode(el.id, { width: nodeWidth, height: nodeHeight });
    } else {
      dagreGraph.setEdge(el.source, el.target);
    }
  });
  dagre.layout(dagreGraph);
  return elements.map((el) => {
    if (isNode(el)) {
      const n = dagreGraph.node(el.id);
      el.position = {
        x: 15 + n.x - nodeWidth / 2,
        y: 15 + n.y - nodeHeight / 2,
      };
    }
    return el;
  });
};

const PipelineBlock = (props) => {
  let elements = [];
  let mapNameToType = {};
  let hasNullPositions = false;

  for (const [productName, product] of Object.entries(props.products)) {
    if (!product.x || !product.y) hasNullPositions = true;
    mapNameToType[productName] = "product";
    elements.push({
      id: productName,
      data: { label: productName, type: "product" },
      position: { x: product.x, y: product.y },
      sourcePosition: "right",
      targetPosition: "left",
      className: styles.ProductNode,
    });
  }

  for (const [plantName, plant] of Object.entries(props.plants)) {
    if (!plant.x || !plant.y) hasNullPositions = true;
    mapNameToType[plantName] = "plant";
    elements.push({
      id: plantName,
      data: { label: plantName, type: "plant" },
      position: { x: plant.x, y: plant.y },
      sourcePosition: "right",
      targetPosition: "left",
      className: styles.PlantNode,
    });

    if (plant.input !== undefined) {
      elements.push({
        id: `${plant.input}-${plantName}`,
        source: plant.input,
        target: plantName,
        animated: true,
        style: { stroke: "black" },
        selectable: false,
      });
    }

    for (const [productName] of Object.entries(
      plant["outputs (tonne/tonne)"]
    )) {
      elements.push({
        id: `${plantName}-${productName}`,
        source: plantName,
        target: productName,
        animated: true,
        style: { stroke: "black" },
        selectable: false,
      });
    }
  }

  const onNodeDoubleClick = (ev, node) => {
    const oldName = node.data.label;
    const newName = window.prompt("Enter new name", oldName);
    if (newName === undefined || newName.length === 0) return;
    if (newName in mapNameToType) return;
    if (node.data.type === "plant") {
      props.onRenamePlant(oldName, newName);
    } else {
      props.onRenameProduct(oldName, newName);
    }
  };

  const onElementsRemove = (elements) => {
    elements.forEach((el) => {
      if (!(el.id in mapNameToType)) return;
      if (el.data.type === "plant") {
        props.onRemovePlant(el.data.label);
      } else {
        props.onRemoveProduct(el.data.label);
      }
    });
  };

  const onNodeDragStop = (ev, node) => {
    if (node.data.type === "plant") {
      props.onMovePlant(node.data.label, node.position.x, node.position.y);
    } else {
      props.onMoveProduct(node.data.label, node.position.x, node.position.y);
    }
  };

  const onConnect = (args) => {
    const sourceType = mapNameToType[args.source];
    const targetType = mapNameToType[args.target];
    if (sourceType === "product" && targetType === "plant") {
      props.onSetPlantInput(args.target, args.source);
    } else if (sourceType === "plant" && targetType === "product") {
      props.onAddPlantOutput(args.source, args.target);
    }
  };

  const onLayout = () => {
    const layoutedElements = getLayoutedElements(elements);
    layoutedElements.forEach((el) => {
      if (isNode(el)) {
        if (el.data.type === "plant") {
          props.onMovePlant(el.data.label, el.position.x, el.position.y);
        } else {
          props.onMoveProduct(el.data.label, el.position.x, el.position.y);
        }
      }
    });
  };

  useEffect(() => {
    if (hasNullPositions) onLayout();
  }, [hasNullPositions]);

  return (
    <>
      <Section title="Pipeline" />
      <Card>
        <div className={styles.PipelineBlock}>
          <ReactFlow
            elements={elements}
            onNodeDoubleClick={onNodeDoubleClick}
            onNodeDragStop={onNodeDragStop}
            onConnect={onConnect}
            onElementsRemove={onElementsRemove}
            deleteKeyCode={46}
            maxZoom={1.25}
            minZoom={0.5}
            snapToGrid={true}
            preventScrolling={false}
          >
            <Background />
            <Controls showInteractive={false} />
          </ReactFlow>
        </div>
        <div style={{ textAlign: "center" }}>
          <Button
            label="Add product"
            kind="inline"
            onClick={props.onAddProduct}
          />
          <Button label="Add plant" kind="inline" onClick={props.onAddPlant} />
          <Button label="Auto Layout" kind="inline" onClick={onLayout} />
          <Button
            label="?"
            kind="inline"
            tooltip="Drag from one connector to another to create links between products and plants. Double click to rename an element. Click an element to select and move it. Press the [Delete] key to remove it."
          />
        </div>
      </Card>
    </>
  );
};

export default PipelineBlock;
