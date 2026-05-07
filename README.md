How to deploy a new arduino-microlab version

Zip the ISS300\hardware\rp2040\1.0.0
Note: it has to be microlab-v1.0.0.zip -> microlab-v1.0.0 -> All the files you would find in 1.0.0
(Aka, there needs to be a top level directory that has the same name as the zip itself)

Update the package_ISS300_index.json to reflect the new version number, size, and hash

Generate checksum and size (using PowerShell Windows)

 Get-FileHash microlab-1.0.0.zip -Algorithm SHA256
Should look something like this in the package_ISS300_index.json
          "checksum": "SHA-256:0127e5a700536ed23e015b354371f44d23b8e0d22f334002bec1fcf3970935b2"

 (Get-Item microlab-1.0.0.zip).Length
Looks like this in the package_ISS300_index.json
          "size": "109593576",

Go to your repo → Releases → Draft a new release
Tag: 1.0.0
Title: MicroLab 1.0.0
Upload microlab-1.0.0.zip as a release asset

Confirm your zip URL matches what's in your JSON. It should be:

Commit and push your package_ISS300_index.json to your repo root on master so the URL is stable:
git add package_ISS300_index.json
   git commit -m "Add board manager package index"
   git push

the json url will then be
https://raw.githubusercontent.com/MarkSkinner92/arduino-microlab/master/package_ISS300_index.json