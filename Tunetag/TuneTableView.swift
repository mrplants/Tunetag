//
//  TuneTableView.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/25/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

class TuneTableView: UITableView, UITableViewDataSource {

    //MARK: Instance Variables
    // TODO: Cache the cover art to file with associated ISRC for offline use.
    var coverArt = [UIImage]()
    
    //MARK: Initializers
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        dataSource = self
    }
    
    //MARK: TableView Datasource
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return UITableViewCell(style: .Default, reuseIdentifier: nil)
    }
}
