# SwiftDeviceDiscovery

[![Build and Test](https://github.com/Apodini/SwiftDeviceDiscovery/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/Apodini/SwiftDeviceDiscovery/actions/workflows/build-and-test.yml)

This repository contains __SwiftDeviceDiscovery__, a highly customizable and easy to use library that allows the discovery of devices in the local network using Apple's mDNS discovery protocol Bonjour. It is able to grant access to and run custom defined actions on the remote device.

## Usage
SwiftDeviceDiscovery can be used to detect devices of certain type in the local network. The discovery is easy to use and can be setup quickly:
```
let discovery = DeviceDiscovery(DeviceIdentifier("_workstation._tcp."))
discovery.configuration = [
    .username: "ubuntu",
    .password: "test1234",
    .runPostActions: true
]
```
The `DeviceDiscovery` is initialized by passing a device identifier that encapsulates the service id. Since the discovery uses mDNS, the device needs to publish itself via avahi or another mDNS implementation. The example above uses "_workstation._tcp." which is the identifier of a raspberry pi using avahi. A `DeviceDiscovery` does only look for one id per search.

A `DeviceDiscovery` can be further customized by pass multiple `ConfigurationProperty`. These are pre-defined or custom options that can be used to provide additional context for the discovery. The pre-defined options need to passed in order to allow __ssh access__. The option `runPostActions` can be set if you have defined post actions that will be executed on the found device. An example: You have a raspberry pi that is a WAP to which are several sub devices connected. To find those, you would need to run some sort of discovery on the device it self as they would not be found in your local network. That's what `PostDiscoveryActions` are for.

You can either define them by implementing the `PostDiscoveryAction` protocol. This gives you access to a `SSHClient` on which you can execute custom commands:
```
public protocol PostDiscoveryAction {
    static var identifier: ActionIdentifier { get }
    
    init()
    
    func run(_ device: Device, on eventLoopGroup: EventLoopGroup, client: SSHClient?) throws -> EventLoopFuture<Int>
}
```
Alternatively, it is also possbile to pass a `DockerDiscoveryAction` that encapsulates a docker image.
```
public struct DockerDiscoveryAction {
    
    public let identifier: ActionIdentifier
    
    public let imageName: String
    
    public let fileUrl: URL
    
    public let options: [DiscoveryDockerOptions]
```

 When using a docker image, you have to follow certain design constrains:
- The result of the docker image has to be a file containing an integer that represents the number of found devices. This has to be done to ensure some sort of unified API. Returning anything other will result in an error.
- The result file has to be written to the specified `fileUrl`. 

You can pass options to a `DockerDiscoveryAction` to customize the run command of the image, e.g. by setting a volume. When your image is on a private repo, it is also expected to provide a `.credentials` option to be able to login into docker. In contrary to the `PostDiscoveryAction`, using a docker image does not constrain you to the swift language. As long as the image meets the afore-mentioned requirements, you can use it with the discovery. 

When you have decided how you want to implement the post actions, you can pass them to this discovery like this:
```
discovery.registerActions(
    .docker(
        DockerDiscoveryAction(
            identifier: ActionIdentifier("Demo_Action"),
            imageName: "my/image:latest-test",
            fileUrl: URL(fileURLWithPath: "path/to/my/results/file.json"),
            options: [
                .custom("--network=host"),
                .port(hostPort: 56700, containerPort: 56700),
                .volume(hostDir: "/usr/demo", containerDir: "/app/tmp"),
                .credentials(username: "myUsername", password: "myPassword"),
                .command("/app/tmp")
            ]
        )
    ),
    .action(MyDemoAction.self)
)
```

Start the discovery by calling run:
```
try discovery.run(1)
```

After an successful search the discovery returns an array of `DiscoveryResult`s. These contain the device and the number of found sub devices for each post discovery action that was specified.

## Contributing
Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/Apodini/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/Apodini/.github/blob/main/CODE_OF_CONDUCT.md) first.

## License 
This project is licensed under the MIT License. See [license](https://github.com/Apodini/SwiftDeviceDiscovery/blob/master/LICENSES/MIT.txt) for more information.
