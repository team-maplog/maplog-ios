//
//  PracticeKakaoMapView.swift
//  Maplog
//
//  Created by 한채림 on 7/10/26.
//

import SwiftUI
import KakaoMapsSDK

struct PracticeKakaoMapView: View {
    @State var draw: Bool = false
    var body: some View {
        KakaoMapView(draw: $draw)
            .onAppear(perform: {
            self.draw = true
            })
            .onDisappear(perform: {
                self.draw = false
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KakaoMapView: UIViewRepresentable {
    @Binding var draw: Bool

    
    func makeUIView(context: Self.Context) -> KMViewContainer {
        let view: KMViewContainer = KMViewContainer()
        view.sizeToFit()
        context.coordinator.createController(view)
        context.coordinator.controller?.prepareEngine()
        
        return view
    }
    
    func updateUIView(_ uiView: KMViewContainer, context: Self.Context) {
        print("updateUIView draw:", draw)
        
        if draw {
            context.coordinator.controller?.activateEngine()
        }
        else {
//            context.coordinator.controller?.resetEngine()
        }
    }
    
    func makeCoordinator() -> KakaoMapCoordinator {
        return KakaoMapCoordinator()
    }
    
    class KakaoMapCoordinator: NSObject, MapControllerDelegate {
        override init() {
            first = true
            super.init()
        }

        
        func createController(_ view: KMViewContainer) {
            viewContainer = view // 전달받은 컨테이너 기억하기(makeUIView에서 만들어진 컨테이너임)
            
            controller = KMController(viewContainer: view)
            controller?.delegate = self
        }
        
        func addViews() {
            print("addViews called")
            
            let defaultPosition: MapPoint = MapPoint(longitude: 126.9780, latitude: 37.5665)
            let mapviewInfo: MapviewInfo = MapviewInfo(viewName: "mapview", viewInfoName: "map", defaultPosition: defaultPosition)
            
            controller?.addView(mapviewInfo)
        }
        
        func addViewSucceeded (_ viewName: String, viewInfoName: String) {
            print("OK")
            
            let mapView = controller?.getView("mapview") as? KakaoMap
                print("mapView exists:", mapView != nil)
                print("mapView viewRect:", mapView?.viewRect as Any)
            
            guard let size = viewContainer?.bounds.size else {
                return
            }
            
            print("현재 container 크기:", size)
            applyMapLayoutIfReady(size) // 현재 컨테이너 크기 적용( 이 시점에서는 지도가 생성됐으니, 기억해 둔 컨테이너에서 현재 크기를 가져와 지도에 적용)
        }
        
        func addViewFailed(_ viewName: String, viewInfoName: String) {
            print("Failed")
        }
        
        private func applyMapLayoutIfReady(_ size: CGSize) {
            guard size.width > 0, size.height > 0 else {
                return
            }
            
            guard let mapView = controller?.getView("mapview") as? KakaoMap else {
                return
            }
            
            mapView.viewRect = CGRect(origin: .zero, size: size)
            print("적용한 mapView 크기:", mapView.viewRect)
            
            if first {
                let position = MapPoint(longitude: 126.9780, latitude: 37.5665)
                
                let cameraUpdate = CameraUpdate.make(target: position, zoomLevel: 10, mapView: mapView)
                
                mapView.moveCamera(cameraUpdate)
                first = false
            }
        }

        
        func containerDidResized(_ size: CGSize) {
            print("containerDidResized called", size)
            applyMapLayoutIfReady(size)
        }
        
                
        
        var controller: KMController?
        var first: Bool
        weak var viewContainer: KMViewContainer? // Coordinator가 컨테이너를 소유하는 게 아니라, 잠깐 참조해서 크기만 확인
    }

}


#Preview {
    PracticeKakaoMapView()
}
