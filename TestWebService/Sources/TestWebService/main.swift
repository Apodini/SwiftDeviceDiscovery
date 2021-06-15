import Apodini
import ApodiniREST

struct TestWebService: WebService {
    var content: some Component {
        Text("Hallo")
    }
    
    var configuration: Configuration {
        ExporterConfiguration()
            .exporter(RESTInterfaceExporter.self)
    }
}

try TestWebService.main()
