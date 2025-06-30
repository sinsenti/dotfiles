#!/bin/bash

# Compile all Java files in the current directory
echo "Compiling all Java files..."
javac *.java

if [ $? -ne 0 ]; then
  echo "Compilation failed. Exiting."
  exit 1
fi

# For each Java file, extract the class name (filename without extension)
for file in *.java; do
  classname="${file%.java}"
  echo "Running $classname..."
  java "$classname"
  echo "----------------------------"
done
