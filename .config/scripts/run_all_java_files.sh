#!/bin/bash

if [ $# -eq 1 ]; then
  # Compile only the specified Java file
  filename="$1.java"
  if [ ! -f "$filename" ]; then
    echo "File $filename does not exist. Exiting."
    exit 1
  fi

  echo "Compiling $filename..."
  javac "$filename"

  if [ $? -ne 0 ]; then
    echo "Compilation failed. Exiting."
    exit 1
  fi

  classname="$1"
  echo "Running $classname..."
  java "$classname"
  echo -e "\n----------------------------"

else
  # Compile all Java files
  echo "Compiling all Java files..."
  javac *.java

  if [ $? -ne 0 ]; then
    echo "Compilation failed. Exiting."
    exit 1
  fi

  # Run all classes
  for file in *.java; do
    classname="${file%.java}"
    echo "Running $classname..."
    java "$classname"
    echo -e "\n----------------------------"
  done
fi

# Cleanup: delete all .class files generated by javac
echo "Cleaning up generated .class files..."
rm -f *.class

echo "Cleanup complete."
