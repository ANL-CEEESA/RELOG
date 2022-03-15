import React from 'react';
import ReactFlow, { Background } from 'react-flow-renderer';
import Section from './Section';
import Card from './Card';
import Button from './Button';
import styles from './PipelineBlock.module.css';


const PipelineBlock = (props) => {
    let elements = [];
    let mapNameToType = {};
    for (const [productName, product] of Object.entries(props.products)) {
        mapNameToType[productName] = "product";
        elements.push({
            id: productName,
            data: { label: productName, type: 'product' },
            position: { x: product.x, y: product.y },
            sourcePosition: 'right',
            targetPosition: 'left',
            className: styles.ProductNode,
        });
    }

    for (const [plantName, plant] of Object.entries(props.plants)) {
        mapNameToType[plantName] = "plant";
        elements.push({
            id: plantName,
            data: { label: plantName, type: 'plant' },
            position: { x: plant.x, y: plant.y },
            sourcePosition: 'right',
            targetPosition: 'left',
            className: styles.PlantNode,
        });

        if (plant.input != undefined) {
            elements.push({
                id: `${plant.input}-${plantName}`,
                source: plant.input,
                target: plantName,
                animated: true,
                style: { stroke: "black" },
                selectable: false,
            });
        }

        for (const [productName, amount] of Object.entries(plant.outputs)) {
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
        if (newName == undefined || newName.length == 0) return;
        if (newName in mapNameToType) return;
        if (node.data.type == "plant") {
            props.onRenamePlant(oldName, newName);
        } else {
            props.onRenameProduct(oldName, newName);
        }
    };

    const onElementsRemove = (elements) => {
        elements.forEach(el => {
            if (!(el.id in mapNameToType)) return;
            if (el.data.type == "plant") {
                props.onRemovePlant(el.data.label);
            } else {
                props.onRemoveProduct(el.data.label);
            }
        });
    };

    const onNodeDragStop = (ev, node) => {
        if (node.data.type == "plant") {
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
                        maxZoom={1}
                        minZoom={1}
                        snapToGrid={true}
                        preventScrolling={false}
                    >
                        <Background />
                    </ReactFlow>
                </div>
                <div style={{ textAlign: 'center' }}>
                    <Button
                        label="Add product"
                        kind="inline"
                        onClick={props.onAddProduct}
                    />
                    <Button
                        label="Add plant"
                        kind="inline"
                        onClick={props.onAddPlant}
                    />
                    <Button
                        label="?"
                        kind="inline"
                        tooltip="Drag from one connector to another to create links between products and plants. Double click to rename an element. Press [Delete] to remove an element."
                    />
                </div>
            </Card>
        </>
    );
};

export default PipelineBlock;